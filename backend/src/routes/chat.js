const router = require('express').Router();
const { auth, optionalAuth, requireRole } = require('../middleware/auth');
const rateLimit = require('../middleware/rateLimit');
const ctrl = require('../controllers/chatController');

// Visitors (no login) get a tighter limit than logged-in users. Window: 10 minutes.
const keyFn = (req) => (req.user ? `u${req.user.id}` : `ip${req.ip}`);
const windowMs = 10 * 60 * 1000;
const message = 'Too many chat messages. Please wait a few minutes and try again.';
const limitVisitor = rateLimit({ windowMs, max: Number(process.env.AI_LIMIT_VISITOR) || 20, keyFn, message });
const limitUser = rateLimit({ windowMs, max: Number(process.env.AI_LIMIT_USER) || 60, keyFn, message });
const limit = (req, res, next) => (req.user ? limitUser : limitVisitor)(req, res, next);
router.post('/', optionalAuth, limit, ctrl.sendMessage);
router.post('/summary', auth, requireRole('landlord'), limitUser, ctrl.summary);
router.post('/actions/:id/confirm', optionalAuth, ctrl.confirmAction);
router.post('/actions/:id/cancel', optionalAuth, ctrl.cancelAction);

module.exports = router;
