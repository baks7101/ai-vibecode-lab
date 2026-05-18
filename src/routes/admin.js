const express = require('express');
const { triageLogs } = require('./chat');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/logs', requireAuth, (req, res) => {
  res.json({
    total: triageLogs.length,
    logs: triageLogs
  });
});

module.exports = router;