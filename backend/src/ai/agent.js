const { toolsForRole, getTool } = require('./tools');
const { buildSystemPrompt } = require('./prompts');
const { AiPendingAction } = require('../models');
const { httpError } = require('../utils/helpers');

const MAX_STEPS = 6;
const MAX_TOKENS = 2048; // reasoning models spend tokens on thinking, so keep some room
const DEFAULT_TIMEOUT_MS = 45000;
const ACTION_TTL_MS = 15 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const NOT_SET_UP = 'The AI Dorm Manager is not set up yet. Add AI_BASE_URL, AI_API_KEY and AI_MODEL to backend/.env and restart the server.';

// --- provider settings (any OpenAI-compatible server: NVIDIA NIM, OpenRouter, Ollama, ...) ---
const isLocalUrl = (url) => {
  try { return ['localhost', '127.0.0.1', '[::1]', '::1'].includes(new URL(url).hostname); } catch { return false; }
};

const timeoutMs = () => {
  const n = Number(process.env.AI_TIMEOUT_MS);
  return Number.isFinite(n) && n >= 1000 ? n : DEFAULT_TIMEOUT_MS;
};

// A key is required, except for a local server (Ollama) which does not use one
const aiConfig = () => {
  const baseUrl = (process.env.AI_BASE_URL || '').trim().replace(/\/+$/, '');
  const apiKey = (process.env.AI_API_KEY || '').trim();
  const model = (process.env.AI_MODEL || '').trim();
  if (!baseUrl || !model || (!apiKey && !isLocalUrl(baseUrl))) throw httpError(503, NOT_SET_UP);
  return { baseUrl, apiKey, model };
};

const callAI = async (cfg, body) => {
  const headers = { 'content-type': 'application/json' };
  if (cfg.apiKey) headers.authorization = `Bearer ${cfg.apiKey}`;
  let res;
  try {
    res = await fetch(`${cfg.baseUrl}/chat/completions`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs()),
    });
  } catch (err) {
    if (err && err.name === 'TimeoutError') throw httpError(502, 'The AI service took too long to answer. Please try again.');
    throw httpError(502, 'Could not reach the AI service. Check your internet connection.');
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    console.error('AI provider error', res.status, text.slice(0, 300)); // never log the key
    if (res.status === 401 || res.status === 403) throw httpError(502, 'The AI API key is invalid or not allowed.');
    if (res.status === 404) throw httpError(502, 'The AI model is not available for this key. Check AI_MODEL in backend/.env.');
    if (res.status === 429) throw httpError(502, 'The AI service is busy right now (its free limit was reached). Please try again in a minute.');
    throw httpError(502, 'The AI service returned an error. Please try again.');
  }
  try {
    return await res.json();
  } catch {
    throw httpError(502, 'The AI service returned an unreadable answer. Please try again.');
  }
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

// --- reading the provider's answer ---
const contentText = (content) => {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content.map((p) => (typeof p === 'string' ? p : (p && typeof p.text === 'string' ? p.text : ''))).join('');
  }
  return '';
};
// Some reasoning models put their thinking inside <think> tags: never show it to the user
const cleanText = (content) => contentText(content)
  .replace(/<think>[\s\S]*?<\/think>/gi, '')
  .replace(/<think>[\s\S]*$/i, '')
  .trim();

// Tool arguments normally arrive as a JSON string; some servers send an object. null = unusable.
const parseArgs = (raw) => {
  if (raw === undefined || raw === null) return {};
  if (typeof raw === 'object') return Array.isArray(raw) ? null : raw;
  if (typeof raw !== 'string') return null;
  if (!raw.trim()) return {};
  try {
    const v = JSON.parse(raw);
    return v && typeof v === 'object' && !Array.isArray(v) ? v : null;
  } catch {
    return null;
  }
};

const normalizeCalls = (message, step) => (Array.isArray(message.tool_calls) ? message.tool_calls : [])
  .filter((c) => c && c.function && typeof c.function.name === 'string')
  .map((c, i) => ({
    id: typeof c.id === 'string' && c.id ? c.id : `call_${step}_${i}`,
    name: c.function.name,
    input: parseArgs(c.function.arguments),
  }));

const echoCall = (c) => ({ id: c.id, type: 'function', function: { name: c.name, arguments: JSON.stringify(c.input || {}) } });
const isUserFacing = (err) => (err.status && err.status < 500) || err.name === 'SequelizeValidationError';

// Tool results are DATA for the model, never instructions. Errors start with "ERROR:".
const handleToolCall = async (call, ctx, pendingActions) => {
  const result = (content, isError = false) => ({ role: 'tool', tool_call_id: call.id, content: isError ? `ERROR: ${content}` : content });
  const tool = getTool(call.name, ctx.role);
  if (!tool) return result('That tool does not exist or is not allowed for this user.', true);
  if (call.input === null) return result('The tool arguments were not valid JSON. Tell the user something went wrong, or try again with valid arguments.', true);
  try {
    if (tool.write) {
      const input = tool.prepare(call.input);
      const summary = String(await tool.describe(input)).slice(0, 500);
      const action = await AiPendingAction.create({
        userId: ctx.user ? ctx.user.id : null, role: ctx.role, toolName: tool.name,
        input: JSON.stringify(input), summary, expiresAt: new Date(Date.now() + ACTION_TTL_MS),
      });
      pendingActions.push({ id: action.id, tool: tool.name, summary, expiresAt: action.expiresAt });
      return result('Proposed to the user. It is waiting for their confirmation and has NOT been done yet. Tell the user to review and confirm it.');
    }
    const out = await tool.run(ctx, call.input);
    return result(JSON.stringify(out === undefined ? null : out).slice(0, 8000));
  } catch (err) {
    if (isUserFacing(err)) return result(err.message, true);
    console.error(`AI tool "${call.name}" failed:`, err);
    return result('The tool failed. Tell the user something went wrong and to try again.', true);
  }
};

// Runs the tool-calling loop. Returns the reply text plus any actions waiting for the user's confirmation.
const runAgent = async (ctx, messages) => {
  const cfg = aiConfig();
  const tools = toolsForRole(ctx.role).map(({ name, description, input_schema }) => ({
    type: 'function',
    function: { name, description, parameters: input_schema },
  }));
  const convo = [
    { role: 'system', content: buildSystemPrompt(ctx) },
    ...messages.map((m) => ({ role: m.role, content: m.content })),
  ];
  const pendingActions = [];

  for (let step = 0; step < MAX_STEPS; step++) {
    const body = { model: cfg.model, max_tokens: MAX_TOKENS, messages: convo };
    if (tools.length) body.tools = tools;
    const data = await callAI(cfg, body);
    const message = Array.isArray(data && data.choices) && data.choices[0] && data.choices[0].message;
    if (!message) throw httpError(502, 'The AI service returned an unexpected answer. Please try again.');

    const text = cleanText(message.content);
    const calls = normalizeCalls(message, step);
    if (!calls.length) {
      const reply = text || (pendingActions.length ? 'Please review and confirm the action below.' : 'Sorry, I could not come up with an answer. Please try again.');
      return { reply, pendingActions };
    }
    convo.push({ role: 'assistant', ...(text ? { content: text } : {}), tool_calls: calls.map(echoCall) });
    for (const c of calls) convo.push(await handleToolCall(c, ctx, pendingActions));
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
