const client = require('prom-client');

const register = new client.Registry();

client.collectDefaultMetrics({ register });

const llmGuardBlocksTotal = new client.Counter({
  name: 'llm_guard_blocks_total',
  help: 'Total requests blocked by LLM-Guard, by scan stage and scanner',
  labelNames: ['stage', 'scanner'],
  registers: [register]
});

const llmGuardScansTotal = new client.Counter({
  name: 'llm_guard_scans_total',
  help: 'Total LLM-Guard scans performed, by scan stage',
  labelNames: ['stage'],
  registers: [register]
});

const llmGuardErrorsTotal = new client.Counter({
  name: 'llm_guard_errors_total',
  help: 'Total LLM-Guard scans that failed to complete, by scan stage',
  labelNames: ['stage'],
  registers: [register]
});

const llmGuardScanDuration = new client.Histogram({
  name: 'llm_guard_scan_duration_seconds',
  help: 'Time taken by LLM-Guard scans, by scan stage',
  labelNames: ['stage'],
  buckets: [0.1, 0.25, 0.5, 1, 2, 5, 10, 15],
  registers: [register]
});

module.exports = {
  register,
  llmGuardBlocksTotal,
  llmGuardScansTotal,
  llmGuardErrorsTotal,
  llmGuardScanDuration
};
