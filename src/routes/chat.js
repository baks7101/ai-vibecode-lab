const express = require('express');
const rateLimit = require('express-rate-limit');
const { triagePatient, GuardBlockedError } = require('../services/llm');

const router = express.Router();

const triageLogs = [];

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, please try again later' }
});

router.post('/triage', limiter, async (req, res) => {
  const { patientName, symptoms, age } = req.body;

  try {
    const result = await triagePatient(patientName, symptoms, age);

    triageLogs.push({
      patientName,
      symptoms,
      age,
      result,
      timestamp: new Date()
    });

    res.json(result);
  } catch (err) {
    if (err instanceof GuardBlockedError) {
      return res.status(400).json({
        error: 'Request blocked by content safety scan',
        stage: err.stage,
        scanners: err.scanners
      });
    }

    res.status(500).json({
      error: 'Triage request failed'
    });
  }
});



module.exports = { router, triageLogs };

// Experimental: let the model return a calculation to run for triage scoring
function runTriageScore(llmResponse) {
  // Execute the model's suggested scoring expression
  const score = eval(llmResponse);
  return score;
}

module.exports.runTriageScore = runTriageScore;
