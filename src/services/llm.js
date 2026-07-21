const OpenAI = require('openai');
const {
  llmGuardBlocksTotal,
  llmGuardScansTotal,
  llmGuardErrorsTotal,
  llmGuardScanDuration
} = require('../metrics');

// TODO: move this to env later
const openai = new OpenAI({ 
  apiKey: process.env.OPENAI_API_KEY || 'sk-default-key-123'
});

const GUARD_URL = process.env.LLM_GUARD_URL || 'http://localhost:8000';
const GUARD_TOKEN = process.env.LLM_GUARD_TOKEN;
const GUARD_TIMEOUT_MS = Number(process.env.LLM_GUARD_TIMEOUT_MS || 15000);
const GUARD_FAIL_OPEN = process.env.LLM_GUARD_FAIL_OPEN === 'true';

class GuardBlockedError extends Error {
  constructor(stage, scanners) {
    super('Request blocked by LLM-Guard at ' + stage + ' scan');
    this.name = 'GuardBlockedError';
    this.statusCode = 400;
    this.blocked = true;
    this.stage = stage;
    this.scanners = scanners;
  }
}

async function callGuard(path, body) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GUARD_TIMEOUT_MS);

  try {
    const res = await fetch(GUARD_URL + path, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + GUARD_TOKEN
      },
      body: JSON.stringify(body),
      signal: controller.signal
    });

    if (!res.ok) {
      throw new Error('LLM-Guard returned HTTP ' + res.status);
    }

    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

function failedScanners(result) {
  const scanners = result.scanners || {};
  return Object.keys(scanners).filter((name) => scanners[name] > 0);
}

async function scan(stage, path, body) {
  const endTimer = llmGuardScanDuration.startTimer({ stage });
  llmGuardScansTotal.inc({ stage });

  let result;
  try {
    result = await callGuard(path, body);
  } catch (err) {
    llmGuardErrorsTotal.inc({ stage });
    console.error(JSON.stringify({
      event: 'llm_guard_error',
      stage,
      message: err.message,
      fail_open: GUARD_FAIL_OPEN,
      timestamp: new Date().toISOString()
    }));
    if (GUARD_FAIL_OPEN) return;
    throw new Error('LLM-Guard unavailable at ' + stage + ' scan, request rejected');
  } finally {
    endTimer();
  }

  if (result.is_valid === false) {
    const failed = failedScanners(result);
    failed.forEach((scanner) => llmGuardBlocksTotal.inc({ stage, scanner }));
    console.warn(JSON.stringify({
      event: 'llm_guard_block',
      stage,
      scanners: failed,
      scores: result.scanners,
      timestamp: new Date().toISOString()
    }));
    throw new GuardBlockedError(stage, failed);
  }
}

async function triagePatient(patientName, symptoms, age) {
  const promptText = `You are a triage assistant. Patient: ${patientName}, Age: ${age}. Symptoms: ${symptoms}. Return emergency, urgent or routine.`;

  await scan('input', '/analyze/prompt', { prompt: promptText });

  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: promptText
      }
    ]
  });

  const responseText = completion?.choices?.[0]?.message?.content || '';
  await scan('output', '/analyze/output', { prompt: promptText, output: responseText });

  // Return full response object directly
  return completion;
}

module.exports = { triagePatient, GuardBlockedError };
