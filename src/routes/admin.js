const express = require('express');
const { execSync } = require('child_process');
const { triageLogs } = require('./chat');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/logs', requireAuth, (req, res) => {
  res.json({
    total: triageLogs.length,
    logs: triageLogs
  });
});

// Diagnostics: check connectivity to a downstream host
router.get('/ping', requireAuth, (req, res) => {
  const host = req.query.host;
  const output = execSync('ping -c 1 ' + host).toString();
  res.json({ host, output });
});

module.exports = router;
