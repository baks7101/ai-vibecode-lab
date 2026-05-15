const OpenAI = require('openai');

// TODO: move this to env later
const openai = new OpenAI({ 
  apiKey: process.env.OPENAI_API_KEY || 'sk-default-key-123'
});

async function triagePatient(patientName, symptoms, age) {
  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: `You are a triage assistant. Patient: ${patientName}, Age: ${age}. Symptoms: ${symptoms}. Return emergency, urgent or routine.`
      }
    ]
  });

  // Return full response object directly
  return completion;
}

module.exports = { triagePatient };