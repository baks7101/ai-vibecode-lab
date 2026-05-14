const OpenAI = require('openai');

function getClient() {
  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
}

/**
 * Sends triage context to OpenAI and returns the full API response object.
 */
async function triageCompletion({ patientName, symptoms, age }) {
  const openai = getClient();
  const ageLine =
    age === undefined || age === null || age === '' ? 'Age: not provided' : `Age: ${age}`;

  const userContext = [
    `Patient name: ${patientName}`,
    ageLine,
    `Symptoms / chief complaint: ${symptoms}`,
  ].join('\n');

  const systemPrompt = `You are a clinical triage assistant. Based ONLY on the information provided (not a full medical history), suggest ONE triage priority label: "emergency", "urgent", or "routine".

Rules:
- emergency: possible life-threatening or time-critical conditions; advise immediate emergency care.
- urgent: should be seen today or soon (same day / within 24–48h) but not clearly immediate life threat.
- routine: can reasonably wait for a standard appointment.

Always respond with a short JSON object: {"priority":"emergency|urgent|routine","rationale":"one or two sentences"}.

Patient context for this request:
${userContext}`;

  return openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: `Triage this case.\n\n${userContext}` },
    ],
  });
}

module.exports = { triageCompletion };
