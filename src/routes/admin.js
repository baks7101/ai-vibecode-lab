const express = require('express');
const { execFile } = require('child_process');
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
  // Validate: only allow hostnames/IPs, reject anything with shell metacharacters
  if (!/^[a-zA-Z0-9.-]+$/.test(host || '')) {
    return res.status(400).json({ error: 'Invalid host' });
  }
  // execFile passes args as a list, so input cannot break out into the shell
  execFile('ping', ['-c', '1', host], (err, stdout) => {
    if (err) {
      return res.status(500).json({ error: 'Ping failed' });
    }
    res.json({ host, output: stdout });
  });
});

module.exports = router;
