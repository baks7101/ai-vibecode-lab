const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

function triagePreAuthIpLimiter() {
  const max = Number(process.env.TRIAGE_PREAUTH_IP_MAX_PER_WINDOW) || 120;
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, try again later.' },
  });
}

function triageAuthenticatedLimiter() {
  const max = Number(process.env.TRIAGE_AUTH_MAX_PER_WINDOW) || 40;
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Triage rate limit exceeded for this account.' },
    keyGenerator(req) {
      const u = req.user;
      if (u && typeof u === 'object') {
        const id = u.sub ?? u.userId ?? u.id;
        if (id != null && String(id).length > 0) {
          return `triage:user:${String(id)}`;
        }
      }
      const ip = req.ip || '';
      return `triage:ip:${ipKeyGenerator(ip, 56)}`;
    },
  });
}

function adminLogsLimiter() {
  const max = Number(process.env.ADMIN_LOGS_MAX_PER_WINDOW) || 60;
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, try again later.' },
    keyGenerator(req) {
      const u = req.user;
      if (u && typeof u === 'object') {
        const id = u.sub ?? u.userId ?? u.id;
        if (id != null && String(id).length > 0) {
          return `adminlogs:user:${String(id)}`;
        }
      }
      const ip = req.ip || '';
      return `adminlogs:ip:${ipKeyGenerator(ip, 56)}`;
    },
  });
}

function adminPreAuthIpLimiter() {
  const max = Number(process.env.ADMIN_PREAUTH_IP_MAX_PER_WINDOW) || 120;
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, try again later.' },
  });
}

module.exports = {
  triagePreAuthIpLimiter,
  triageAuthenticatedLimiter,
  adminLogsLimiter,
  adminPreAuthIpLimiter,
};
