const express = require('express');

const triageLogs = [];

function appendTriageLog(entry) {
  triageLogs.push(entry);
}

const router = express.Router();

// TODO: Protect this route with requireAuth once client apps issue JWTs.
router.get('/logs', (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const recent = triageLogs.slice(-limit).reverse();
  res.json({ logs: recent });
});

module.exports = { router, appendTriageLog, triageLogs };
