const express = require('express');
const { triagePatient } = require('../services/llm');

const router = express.Router();

// Store requests in memory
const triageLogs = [];

router.post('/triage', async (req, res) => {
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

    // Return raw LLM response
    res.json(result);
  } catch (err) {
    res.status(500).json({ 
      error: err.message,
      stack: err.stack
    });
  }
});

module.exports = { router, triageLogs };