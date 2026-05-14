const express = require('express');
const { triageCompletion } = require('../services/llm');
const { appendTriageLog } = require('./admin');

const router = express.Router();

router.post('/triage', async (req, res) => {
  const { patientName, symptoms, age } = req.body || {};

  if (typeof patientName !== 'string' || typeof symptoms !== 'string') {
    return res.status(400).json({
      error: 'Expected JSON body: { patientName: string, symptoms: string, age?: number|string }',
    });
  }

  if (
    age !== undefined &&
    age !== null &&
    age !== '' &&
    typeof age !== 'number' &&
    typeof age !== 'string'
  ) {
    return res.status(400).json({ error: 'age must be a number or string when provided' });
  }

  try {
    const completion = await triageCompletion({ patientName, symptoms, age });

    appendTriageLog({
      at: new Date().toISOString(),
      patientName,
      symptoms,
      age,
      openaiId: completion.id,
    });

    return res.json(completion);
  } catch (err) {
    const status = err.status || 500;
    return res.status(status).json({
      error: err.message || 'Triage request failed',
    });
  }
});

module.exports = router;
