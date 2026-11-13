const router = require('express').Router();
const bcrypt = require('bcrypt');
const { User, Lease, Room } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { notify } = require('../utils/notify');

router.use(auth, requireRole('landlord'));

const withLease = [{ model: Lease, as: 'leases', where: { status: 'active' }, required: false, include: [{ model: Room, as: 'room' }] }];

router.get('/', asyncHandler(async (req, res) => {
  const where = { role: 'tenant' };
  if (req.query.status) where.status = req.query.status;
  res.json(await User.findAll({ where, include: withLease, order: [['fullName', 'ASC']] }));
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const t = await User.findOne({ where: { id: req.params.id, role: 'tenant' }, include: withLease });
  if (!t) return res.status(404).json({ message: 'Tenant not found' });
  res.json(t);
}));

// Landlord creates a tenant account directly (active immediately)
router.post('/', asyncHandler(async (req, res) => {
  const { fullName, email, password, contactNumber } = req.body;
  if (!fullName || !email || !password || password.length < 8) return res.status(400).json({ message: 'fullName, email and a password of at least 8 characters are required' });
  const t = await User.create({
    fullName, email: String(email).toLowerCase().trim(), contactNumber,
    passwordHash: await bcrypt.hash(password, 10), role: 'tenant', status: 'active',
  });
  res.status(201).json(t);
}));

router.put('/:id', asyncHandler(async (req, res) => {
  const t = await User.findOne({ where: { id: req.params.id, role: 'tenant' } });
  if (!t) return res.status(404).json({ message: 'Tenant not found' });
  const { fullName, email, contactNumber } = req.body;
  await t.update({ fullName, email: email && String(email).toLowerCase().trim(), contactNumber });
  res.json(t);
}));

router.patch('/:id/approve', asyncHandler(async (req, res) => {
  const t = await User.findOne({ where: { id: req.params.id, role: 'tenant' } });
  if (!t) return res.status(404).json({ message: 'Tenant not found' });
  await t.update({ status: 'active' });
  await notify(t.id, 'account', 'Your account has been approved. Welcome to Git-Inside!', 'user', t.id);
  res.json(t);
}));

router.patch('/:id/archive', asyncHandler(async (req, res) => {
  const t = await User.findOne({ where: { id: req.params.id, role: 'tenant' } });
  if (!t) return res.status(404).json({ message: 'Tenant not found' });
  const active = await Lease.count({ where: { tenantId: t.id, status: 'active' } });
  if (active) return res.status(409).json({ message: 'End the tenant\'s active lease before archiving' });
  await t.update({ status: 'archived' });
  res.json(t);
}));

module.exports = router;
