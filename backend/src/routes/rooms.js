const router = require('express').Router();
const { Room, Lease, User } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');

router.use(auth, requireRole('landlord'));

const include = [{
  model: Lease, as: 'leases', where: { status: 'active' }, required: false,
  include: [{ model: User, as: 'tenant', attributes: ['id', 'fullName', 'contactNumber'] }],
}];

const present = (room) => {
  const j = room.toJSON();
  j.occupants = (j.leases || []).length;
  j.occupancyStatus = j.isArchived ? 'archived' : j.occupants === 0 ? 'vacant' : j.occupants >= j.capacity ? 'full' : 'occupied';
  return j;
};

router.get('/', asyncHandler(async (req, res) => {
  const where = req.query.archived === 'true' ? {} : { isArchived: false };
  const rooms = await Room.findAll({ where, include, order: [['roomNumber', 'ASC']] });
  let list = rooms.map(present);
  if (req.query.status) list = list.filter((r) => r.occupancyStatus === req.query.status);
  res.json(list);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const room = await Room.findByPk(req.params.id, { include });
  if (!room) return res.status(404).json({ message: 'Room not found' });
  res.json(present(room));
}));

router.post('/', asyncHandler(async (req, res) => {
  const { roomNumber, description, monthlyRate, capacity } = req.body;
  if (!roomNumber || monthlyRate === undefined) return res.status(400).json({ message: 'roomNumber and monthlyRate are required' });
  res.status(201).json(await Room.create({ roomNumber, description, monthlyRate, capacity: capacity || 1 }));
}));

router.put('/:id', asyncHandler(async (req, res) => {
  const room = await Room.findByPk(req.params.id);
  if (!room) return res.status(404).json({ message: 'Room not found' });
  const { roomNumber, description, monthlyRate, capacity } = req.body;
  await room.update({ roomNumber, description, monthlyRate, capacity });
  res.json(room);
}));

router.patch('/:id/archive', asyncHandler(async (req, res) => {
  const room = await Room.findByPk(req.params.id);
  if (!room) return res.status(404).json({ message: 'Room not found' });
  if (await Lease.count({ where: { roomId: room.id, status: 'active' } })) return res.status(409).json({ message: 'Room still has active tenants' });
  await room.update({ isArchived: true });
  res.json(room);
}));

router.patch('/:id/restore', asyncHandler(async (req, res) => {
  const room = await Room.findByPk(req.params.id);
  if (!room) return res.status(404).json({ message: 'Room not found' });
  await room.update({ isArchived: false });
  res.json(room);
}));

module.exports = router;
