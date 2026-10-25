const router = require('express').Router();
const { auth, optionalAuth, requireRole } = require('../middleware/auth');
const rateLimit = require('../middleware/rateLimit');
const { asyncHandler, httpError } = require('../utils/helpers');
const { runAgent, resolveAction, sanitizeMessages } = require('../ai/agent');

// Visitors (no login) get a tighter limit than logged-in users. Window: 10 minutes.
const keyFn = (req) => (req.user ? `u${req.user.id}` : `ip${req.ip}`);
const windowMs = 10 * 60 * 1000;
const message = 'Too many chat messages. Please wait a few minutes and try again.';
const limitVisitor = rateLimit({ windowMs, max: Number(process.env.AI_LIMIT_VISITOR) || 20, keyFn, message });
const limitUser = rateLimit({ windowMs, max: Number(process.env.AI_LIMIT_USER) || 60, keyFn, message });
const limit = (req, res, next) => (req.user ? limitUser : limitVisitor)(req, res, next);

const makeCtx = (req) => ({ user: req.user || null, role: req.user ? req.user.role : 'visitor' });

// Chat. Works without a token (visitor mode) or with one (tenant / landlord mode).
// Body: { messages: [{ role: 'user'|'assistant', content: '...' }, ...] }  -> { role, reply, pendingActions }
router.post('/', optionalAuth, limit, asyncHandler(async (req, res) => {
  const messages = sanitizeMessages(req.body.messages);
  if (!messages) throw httpError(400, 'messages must be a list of {role, content} that ends with a user message');
  const ctx = makeCtx(req);
  res.json({ role: ctx.role, ...(await runAgent(ctx, messages)) });
}));

// Landlord dashboard button: "Generate AI summary"
router.post('/summary', auth, requireRole('landlord'), limitUser, asyncHandler(async (req, res) => {
  const period = req.body.period ? ` for ${req.body.period}` : ' for this month';
  const ctx = makeCtx(req);
  res.json({ role: ctx.role, ...(await runAgent(ctx, [{ role: 'user', content: `Write the dormitory summary${period}.` }])) });
}));

// The user confirms or cancels an action the AI proposed
router.post('/actions/:id/confirm', optionalAuth, asyncHandler(async (req, res) => {
  res.json(await resolveAction(req.params.id, makeCtx(req), 'confirm'));
}));
router.post('/actions/:id/cancel', optionalAuth, asyncHandler(async (req, res) => {
  res.json(await resolveAction(req.params.id, makeCtx(req), 'cancel'));
}));

module.exports = router;
