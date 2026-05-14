const jwt = require('jsonwebtoken');

function jwtSecret() {
  return process.env.JWT_SECRET || 'default_secret';
}

/**
 * Verifies Bearer JWT and attaches payload to req.user.
 */
function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  const token = header.slice('Bearer '.length).trim();
  if (!token) {
    return res.status(401).json({ error: 'Missing token' });
  }
  try {
    req.user = jwt.verify(token, jwtSecret());
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth, jwtSecret };
