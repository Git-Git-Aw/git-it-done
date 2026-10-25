const router = require('express').Router();
const { Lease, Room, User } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { notify } = require('../utils/notify');

router.use(auth, requireRole('landlord'));

const include = [
  { model: Room, as: 'room' },
  { model: User, as: 'tenant', attributes: ['id', 'fullName', 'email', 'contactNumber'] },
];

router.get('/', asyncHandler(async (req, res) => {
  const where = {};
  if (req.query.status) where.status = req.query.status;
  res.json(await Lease.findAll({ where, include, order: [['startDate', 'DESC']] }));
}));

// Assign a tenant to a room
router.post('/', asyncHandler(async (req, res) => {
  const { tenantId, roomId, startDate, endDate, monthlyRent, dueDay } = req.body;
  if (!tenantId || !roomId || !startDate) return res.status(400).json({ message: 'tenantId, roomId and startDate are required' });
  const tenant = await User.findOne({ where: { id: tenantId, role: 'tenant', status: 'active' } });
  if (!tenant) return res.status(404).json({ message: 'Active tenant not found' });
  const room = await Room.findByPk(roomId);
  if (!room || room.isArchived) return res.status(404).json({ message: 'Room not found or archived' });
  if (await Lease.count({ where: { tenantId, status: 'active' } })) return res.status(409).json({ message: 'Tenant already has an active lease' });
  if ((await Lease.count({ where: { roomId, status: 'active' } })) >= room.capacity) return res.status(409).json({ message: 'Room is already full' });
  const lease = await Lease.create({ tenantId, roomId, startDate, endDate, monthlyRent: monthlyRent ?? room.monthlyRate, dueDay: dueDay || 5 });
  await notify(tenant.id, 'lease', `You have been assigned to Room ${room.roomNumber}.`, 'lease', lease.id);
  res.status(201).json(await Lease.findByPk(lease.id, { include }));
}));

router.put('/:id', asyncHandler(async (req, res) => {
  const lease = await Lease.findByPk(req.params.id);
  if (!lease) return res.status(404).json({ message: 'Lease not found' });
  const { startDate, endDate, monthlyRent, dueDay } = req.body;
  await lease.update({ startDate, endDate, monthlyRent, dueDay });
  res.json(await Lease.findByPk(lease.id, { include }));
}));

router.patch('/:id/end', asyncHandler(async (req, res) => {
  const lease = await Lease.findByPk(req.params.id);
  if (!lease) return res.status(404).json({ message: 'Lease not found' });
  await lease.update({ status: 'ended', endDate: req.body.endDate || lease.endDate || new Date().toISOString().slice(0, 10) });
  res.json(await Lease.findByPk(lease.id, { include }));
}));

module.exports = router;
