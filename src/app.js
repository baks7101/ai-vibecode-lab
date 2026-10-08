const express = require('express');
const helmet = require('helmet');
const dotenv = require('dotenv');

dotenv.config();

const app = express();

// Security headers (fixes DAST findings: CSP, anti-clickjacking, no-sniff, etc.)
app.use(helmet());

app.use(express.json());

const { register } = require('./metrics');

const chatRoutes = require('./routes/chat');
const adminRoutes = require('./routes/admin');

app.use('/api/chat', chatRoutes.router);
app.use('/api/admin', adminRoutes);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Error handler
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,
    stack: err.stack
  });
});

const PORT = process.env.PORT || 3000;

// Keep a handle on the server so it can be closed cleanly on shutdown.
const server = app.listen(PORT, () => {
  console.log(`MediTriage API running on port ${PORT}`);
});

// ---------------------------------------------------------------------
// Graceful shutdown
// Kubernetes sends SIGTERM before stopping a pod, then waits 30 seconds
// before SIGKILL. Node running as PID 1 ignores SIGTERM unless the app
// handles it, so without this every pod stop was force-killed mid-request.
// ---------------------------------------------------------------------

// Must stay below the pod's terminationGracePeriodSeconds (default 30s),
// so the app always finishes its own shutdown before Kubernetes kills it.
const SHUTDOWN_TIMEOUT_MS = Number(process.env.SHUTDOWN_TIMEOUT_MS || 10000);

let shuttingDown = false;

function shutdown(signal) {
  // Ignore repeat signals while a shutdown is already in progress.
  if (shuttingDown) return;
  shuttingDown = true;

  console.log(JSON.stringify({
    event: 'shutdown_started',
    signal,
    timestamp: new Date().toISOString()
  }));

  // Stop accepting new connections; let in-flight requests finish.
  server.close((err) => {
    if (err) {
      console.error(JSON.stringify({
        event: 'shutdown_error',
        signal,
        error: err.message,
        timestamp: new Date().toISOString()
      }));
      process.exit(1);
    }
    console.log(JSON.stringify({
      event: 'shutdown_complete',
      signal,
      timestamp: new Date().toISOString()
    }));
    process.exit(0);
  });

  // Safety net: if requests hang (e.g. a slow OpenAI call), exit anyway
  // rather than waiting to be killed. unref() stops this timer from
  // keeping the process alive on its own.
  setTimeout(() => {
    console.error(JSON.stringify({
      event: 'shutdown_forced',
      signal,
      timeoutMs: SHUTDOWN_TIMEOUT_MS,
      timestamp: new Date().toISOString()
    }));
    process.exit(1);
  }, SHUTDOWN_TIMEOUT_MS).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM')); // sent by Kubernetes / docker stop
process.on('SIGINT', () => shutdown('SIGINT'));   // sent by Ctrl+C locally

module.exports = app;
