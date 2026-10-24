const router = require('express').Router();
const { Payment, Lease, Room, User } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler, presentPayment, currentPeriod, isPeriod } = require('../utils/helpers');

router.use(auth, requireRole('landlord'));

const csvCell = (v) => {
  let s = v === null || v === undefined ? '' : String(v);
  if (/^[=+\-@]/.test(s)) s = `'${s}`; // neutralise spreadsheet formulas
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

// Monthly payment summary: GET /api/reports/monthly?month=YYYY-MM&format=csv|json
router.get('/monthly', asyncHandler(async (req, res) => {
  const month = req.query.month || currentPeriod();
  if (!isPeriod(month)) return res.status(400).json({ message: 'month must be YYYY-MM' });
  const rows = (await Payment.findAll({
    where: { period: month },
    include: [
      { model: User, as: 'tenant', attributes: ['id', 'fullName'] },
      { model: Lease, as: 'lease', include: [{ model: Room, as: 'room', attributes: ['roomNumber'] }] },
    ],
  })).map(presentPayment);
  rows.sort((a, b) => String(a.lease.room.roomNumber).localeCompare(String(b.lease.room.roomNumber), undefined, { numeric: true }));

  const totals = {
    billed: rows.reduce((s, r) => s + r.amountDue, 0),
    collected: rows.reduce((s, r) => s + r.amountPaid, 0),
    outstanding: rows.reduce((s, r) => s + r.balance, 0),
  };

  if (req.query.format === 'csv') {
    const header = ['Room', 'Tenant', 'Period', 'Due Date', 'Amount Due', 'Amount Paid', 'Balance', 'Status', 'Paid At'];
    const lines = [header.join(',')].concat(rows.map((r) => [
      r.lease.room.roomNumber, r.tenant.fullName, r.period, r.dueDate, r.amountDue, r.amountPaid, r.balance, r.displayStatus, r.paidAt ? new Date(r.paidAt).toISOString() : '',
    ].map(csvCell).join(',')));
    lines.push(['TOTAL', '', '', '', totals.billed, totals.collected, totals.outstanding, '', ''].join(','));
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="payments-${month}.csv"`);
    return res.send(lines.join('\n'));
  }
  res.json({ month, totals, rows });
}));

module.exports = router;
