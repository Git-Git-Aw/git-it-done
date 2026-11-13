const router = require('express').Router();
const { Op } = require('sequelize');
const { Payment, Lease, Room, User } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');
const { asyncHandler, presentPayment, todayStr, currentPeriod, isPeriod } = require('../utils/helpers');
const { generateBills, markPaid } = require('../services/billing');
const { notify, notifyLandlords } = require('../utils/notify');

router.use(auth);

const landlordInclude = [
  { model: User, as: 'tenant', attributes: ['id', 'fullName', 'contactNumber'] },
  { model: Lease, as: 'lease', include: [{ model: Room, as: 'room', attributes: ['id', 'roomNumber'] }] },
];

/* ---------- Tenant ---------- */
router.get('/mine', requireRole('tenant'), asyncHandler(async (req, res) => {
  const rows = await Payment.findAll({
    where: { tenantId: req.user.id },
    include: [{ model: Lease, as: 'lease', include: [{ model: Room, as: 'room', attributes: ['id', 'roomNumber'] }] }],
    order: [['period', 'DESC']],
  });
  res.json(rows.map(presentPayment));
}));

// Upload proof of payment (receipt photo) -> waits for landlord confirmation
router.post('/:id/proof', requireRole('tenant'), upload.single('proof'), asyncHandler(async (req, res) => {
  const p = await Payment.findOne({ where: { id: req.params.id, tenantId: req.user.id } });
  if (!p) return res.status(404).json({ message: 'Payment not found' });
  if (p.status === 'paid') return res.status(409).json({ message: 'This bill is already paid' });
  if (!req.file) return res.status(400).json({ message: 'Attach a receipt image in the "proof" field' });
  await p.update({ proofPath: `/uploads/${req.file.filename}`, status: 'pending_confirmation', method: req.body.method || p.method, remarks: req.body.remarks || p.remarks });
  await notifyLandlords('payment_proof', `${req.user.fullName} uploaded proof of payment for ${p.period}.`, 'payment', p.id);
  res.json(presentPayment(p));
}));

/* ---------- Landlord ---------- */
router.get('/', requireRole('landlord'), asyncHandler(async (req, res) => {
  const { status, period, tenantId } = req.query;
  const where = {};
  if (period) where.period = period;
  if (tenantId) where.tenantId = tenantId;
  if (status === 'overdue') { where.status = 'unpaid'; where.dueDate = { [Op.lt]: todayStr() }; }
  else if (status === 'unpaid') { where.status = 'unpaid'; where.dueDate = { [Op.gte]: todayStr() }; }
  else if (status) where.status = status;
  const rows = await Payment.findAll({ where, include: landlordInclude, order: [['period', 'DESC'], ['dueDate', 'ASC']] });
  res.json(rows.map(presentPayment));
}));

// Generate billing statements for all active leases for a period (default: current month)
router.post('/generate', requireRole('landlord'), asyncHandler(async (req, res) => {
  const period = req.body.period || currentPeriod();
  if (!isPeriod(period)) return res.status(400).json({ message: 'period must be YYYY-MM' });
  res.status(201).json(await generateBills(period));
}));

// Landlord records a payment manually (cash, GCash received, etc.)
router.patch('/:id/record', requireRole('landlord'), asyncHandler(async (req, res) => {
  const p = await Payment.findByPk(req.params.id);
  if (!p) return res.status(404).json({ message: 'Payment not found' });
  const amount = Number(req.body.amountPaid ?? (p.amountDue - p.amountPaid));
  if (!(amount > 0)) return res.status(400).json({ message: 'amountPaid must be greater than 0' });
  await markPaid(p, amount, { method: req.body.method || p.method, remarks: req.body.remarks || p.remarks });
  res.json(presentPayment(await Payment.findByPk(p.id, { include: landlordInclude })));
}));

// Landlord confirms a receipt the tenant uploaded
router.patch('/:id/confirm', requireRole('landlord'), asyncHandler(async (req, res) => {
  const p = await Payment.findByPk(req.params.id);
  if (!p) return res.status(404).json({ message: 'Payment not found' });
  if (p.status !== 'pending_confirmation') return res.status(409).json({ message: 'No uploaded receipt is waiting for confirmation' });
  const amount = Number(req.body.amountPaid ?? (p.amountDue - p.amountPaid));
  await markPaid(p, amount, { remarks: req.body.remarks || p.remarks });
  res.json(presentPayment(await Payment.findByPk(p.id, { include: landlordInclude })));
}));

router.patch('/:id/reject', requireRole('landlord'), asyncHandler(async (req, res) => {
  const p = await Payment.findByPk(req.params.id);
  if (!p) return res.status(404).json({ message: 'Payment not found' });
  if (p.status !== 'pending_confirmation') return res.status(409).json({ message: 'No uploaded receipt is waiting for confirmation' });
  await p.update({ status: 'unpaid', proofPath: null, remarks: req.body.remarks || 'Receipt rejected' });
  await notify(p.tenantId, 'payment', `Your receipt for ${p.period} was rejected: ${p.remarks}`, 'payment', p.id);
  res.json(presentPayment(p));
}));

module.exports = router;
