const { asyncHandler, httpError } = require('../utils/helpers');
const { runAgent, resolveAction, sanitizeMessages } = require('../ai/agent');

const makeCtx = (req) => ({ user: req.user || null, role: req.user ? req.user.role : 'visitor' });

// Chat. Works without a token (visitor mode) or with one (tenant / landlord mode).
// Body: { messages: [{ role: 'user'|'assistant', content: '...' }, ...] }  -> { role, reply, pendingActions }
const sendMessage = asyncHandler(async (req, res) => {
  const messages = sanitizeMessages(req.body.messages);
  if (!messages) throw httpError(400, 'messages must be a list of {role, content} that ends with a user message');
  const ctx = makeCtx(req);
  res.json({ role: ctx.role, ...(await runAgent(ctx, messages)) });
});

// Landlord dashboard button: "Generate AI summary"
const summary = asyncHandler(async (req, res) => {
  const period = req.body.period ? ` for ${req.body.period}` : ' for this month';
  const ctx = makeCtx(req);
  res.json({ role: ctx.role, ...(await runAgent(ctx, [{ role: 'user', content: `Write the dormitory summary${period}.` }])) });
});

// The user confirms or cancels an action the AI proposed
const confirmAction = asyncHandler(async (req, res) => {
  res.json(await resolveAction(req.params.id, makeCtx(req), 'confirm'));
});

const cancelAction = asyncHandler(async (req, res) => {
  res.json(await resolveAction(req.params.id, makeCtx(req), 'cancel'));
});

module.exports = { sendMessage, summary, confirmAction, cancelAction };
