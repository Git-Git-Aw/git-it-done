const crypto = require('crypto');

const pad = (n) => String(n).padStart(2, '0');

exports.todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

exports.currentPeriod = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
};

exports.isPeriod = (s) => /^\d{4}-(0[1-9]|1[0-2])$/.test(s || '');

exports.dueDateFor = (period, dueDay) => `${period}-${pad(Math.min(Math.max(Number(dueDay) || 5, 1), 28))}`;

exports.asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

exports.sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

// payment JSON with computed balance + overdue flag
exports.presentPayment = (p) => {
  const j = p.toJSON ? p.toJSON() : p;
  const today = exports.todayStr();
  j.balance = Math.max(j.amountDue - j.amountPaid, 0);
  j.displayStatus = j.status === 'unpaid' && j.dueDate < today ? 'overdue' : j.status;
  return j;
};

exports.httpError = (status, message) => {
  const e = new Error(message);
  e.status = status;
  return e;
};
