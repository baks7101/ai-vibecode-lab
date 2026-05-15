const express = require('express');
const { triageLogs } = require('./chat');

const router = express.Router();

// TODO: add auth later
router.get('/logs', (req, res) => {
  res.json({
    total: triageLogs.length,
    logs: triageLogs
  });
});

module.exports = router;