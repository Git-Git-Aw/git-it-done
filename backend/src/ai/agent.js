const { toolsForRole, getTool } = require('./tools');
const { buildSystemPrompt } = require('./prompts');
const { AiPendingAction } = require('../models');
const { httpError } = require('../utils/helpers');

const API_URL = 'https://api.anthropic.com/v1/messages';
const MAX_STEPS = 6;
const ACTION_TTL_MS = 15 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const modelName = () => process.env.ANTHROPIC_MODEL || 'claude-haiku-5-5';

const callClaude = async (body) => {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw httpError(503, 'The AI Dorm Manager is not set up yet. Add ANTHROPIC_API_KEY to backend/.env and restart the server.');
  let res;
  try {
    res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(45000),
    });
  } catch {
    throw httpError(502, 'Could not reach the AI service. Check your internet connection.');
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    console.error('Claude API error', res.status, text.slice(0, 300));
    throw httpError(502, res.status === 401 ? 'The AI API key is invalid.' : 'The AI service returned an error. Please try again.');
  }
  return res.json();
};

// Messages come from the client, so keep only plain, short user/assistant text
const sanitizeMessages = (raw) => {
  if (!Array.isArray(raw)) return null;
  const msgs = raw.slice(-12)
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string' && m.content.trim())
    .map((m) => ({ role: m.role, content: m.content.trim().slice(0, 1000) }));
  while (msgs.length && msgs[0].role !== 'user') msgs.shift();
  if (!msgs.length || msgs[msgs.length - 1].role !== 'user') return null;
  return msgs;
};

const textOf = (blocks) => blocks.filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim();
const echoBlocks = (blocks) => blocks.filter((b) => b.type === 'text' || b.type === 'tool_use')
  .map((b) => (b.type === 'text' ? { type: 'text', text: b.text } : { type: 'tool_use', id: b.id, name: b.name, input: b.input || {} }));
const isUserFacing = (err) => (err.status && err.status < 500) || err.name === 'SequelizeValidationError';

const handleToolUse = async (block, ctx, pendingActions) => {
  const result = (content, isError = false) => ({ type: 'tool_result', tool_use_id: block.id, content, ...(isError ? { is_error: true } : {}) });
  const tool = getTool(block.name, ctx.role);
  if (!tool) return result('That tool does not exist or is not allowed for this user.', true);
  try {
    if (tool.write) {
      const input = tool.prepare(block.input || {});
      const summary = String(await tool.describe(input)).slice(0, 500);
      const action = await AiPendingAction.create({
        userId: ctx.user ? ctx.user.id : null, role: ctx.role, toolName: tool.name,
        input: JSON.stringify(input), summary, expiresAt: new Date(Date.now() + ACTION_TTL_MS),
      });
      pendingActions.push({ id: action.id, tool: tool.name, summary, expiresAt: action.expiresAt });
      return result('Proposed to the user. It is waiting for their confirmation and has NOT been done yet. Tell the user to review and confirm it.');
    }
    const out = await tool.run(ctx, block.input || {});
    return result(JSON.stringify(out === undefined ? null : out).slice(0, 8000));
  } catch (err) {
    if (isUserFacing(err)) return result(err.message, true);
    console.error(`AI tool "${block.name}" failed:`, err);
    return result('The tool failed. Tell the user something went wrong and to try again.', true);
  }
};

// Runs the tool-calling loop. Returns the reply text plus any actions waiting for the user's confirmation.
const runAgent = async (ctx, messages) => {
  const tools = toolsForRole(ctx.role).map(({ name, description, input_schema }) => ({ name, description, input_schema }));
  const system = buildSystemPrompt(ctx);
  const convo = messages.map((m) => ({ role: m.role, content: m.content }));
  const pendingActions = [];

  for (let step = 0; step < MAX_STEPS; step++) {
    const data = await callClaude({ model: modelName(), max_tokens: 1024, system, tools, messages: convo });
    const blocks = Array.isArray(data.content) ? data.content : [];
    if (data.stop_reason !== 'tool_use') {
      const reply = textOf(blocks) || (pendingActions.length ? 'Please review and confirm the action below.' : 'Sorry, I could not come up with an answer. Please try again.');
      return { reply, pendingActions };
    }
    convo.push({ role: 'assistant', content: echoBlocks(blocks) });
    const results = [];
    for (const b of blocks.filter((x) => x.type === 'tool_use')) results.push(await handleToolUse(b, ctx, pendingActions));
    convo.push({ role: 'user', content: results });
  }
  return { reply: 'Sorry, I could not finish that request. Please try rephrasing it.', pendingActions };
};

// The user pressed Confirm or Cancel on a proposed action
const resolveAction = async (id, ctx, decision) => {
  if (!UUID.test(id)) throw httpError(404, 'Action not found');
  const action = await AiPendingAction.findByPk(id);
  if (!action) throw httpError(404, 'Action not found');
  if ((action.userId || null) !== (ctx.user ? ctx.user.id : null) || action.role !== ctx.role) throw httpError(403, 'This action does not belong to you');
  if (action.status !== 'pending') throw httpError(409, `This action was already ${action.status}`);
  if (new Date(action.expiresAt) < new Date()) {
    await action.update({ status: 'cancelled', result: 'expired' });
    throw httpError(410, 'This action expired. Please ask again.');
  }
  if (decision === 'cancel') {
    await action.update({ status: 'cancelled' });
    return { status: 'cancelled', message: 'Cancelled. Nothing was changed.' };
  }
  const tool = getTool(action.toolName, action.role);
  if (!tool) throw httpError(404, 'This action is no longer available');

  // Claim it first so a double tap cannot run it twice
  const [claimed] = await AiPendingAction.update({ status: 'executed' }, { where: { id: action.id, status: 'pending' } });
  if (!claimed) throw httpError(409, 'This action was already handled');
  try {
    const result = await tool.run(ctx, JSON.parse(action.input));
    await AiPendingAction.update({ result: JSON.stringify(result).slice(0, 2000) }, { where: { id: action.id } });
    return { status: 'executed', message: tool.successMessage ? tool.successMessage(result) : 'Done.', result };
  } catch (err) {
    await AiPendingAction.update({ status: 'failed', result: String(err.message).slice(0, 500) }, { where: { id: action.id } });
    if (isUserFacing(err)) throw err;
    throw err;
  }
};

module.exports = { runAgent, resolveAction, sanitizeMessages };
