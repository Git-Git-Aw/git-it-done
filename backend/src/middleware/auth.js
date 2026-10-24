const jwt = require('jsonwebtoken');
const { User } = require('../models');
const { asyncHandler } = require('../utils/helpers');

const SECRET = () => process.env.JWT_SECRET || 'dev-secret-change-me';

exports.signToken = (user) =>
  jwt.sign({ id: user.id, role: user.role }, SECRET(), { expiresIn: process.env.JWT_EXPIRES_IN || '8h' });

exports.auth = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'Authentication required' });
  let payload;
  try {
    payload = jwt.verify(token, SECRET());
  } catch {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
  const user = await User.findByPk(payload.id);
  if (!user || user.status !== 'active') return res.status(401).json({ message: 'Account is not active' });
  req.user = user;
  next();
});

exports.requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ message: 'You do not have access to this resource' });

// Token is optional: no header = visitor (req.user = null); a bad token is still rejected
exports.optionalAuth = (req, res, next) => {
  if (!(req.headers.authorization || '').startsWith('Bearer ')) { req.user = null; return next(); }
  return exports.auth(req, res, next);
};
