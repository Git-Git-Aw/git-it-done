const router = require('express').Router();
const { Op } = require('sequelize');
const { Room, Lease, Payment, Announcement, Notification, User } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler, presentPayment, currentPeriod, isPeriod } = require('../utils/helpers');
const { landlordSummary } = require('../services/dashboard');

router.use(auth);

router.get('/tenant', requireRole('tenant'), asyncHandler(async (req, res) => {
  const lease = await Lease.findOne({ where: { tenantId: req.user.id, status: 'active' }, include: [{ model: Room, as: 'room' }] });
  const open = await Payment.findAll({ where: { tenantId: req.user.id, status: { [Op.ne]: 'paid' } }, order: [['dueDate', 'ASC']] });
  const balance = open.reduce((s, p) => s + (p.amountDue - p.amountPaid), 0);
  const next = open.find((p) => p.status === 'unpaid') || open[0] || null;
  res.json({
    tenant: req.user,
    lease,
    room: lease ? lease.room : null,
    balance,
    nextDue: next ? presentPayment(next) : null,
    announcements: await Announcement.findAll({ where: { isArchived: false }, order: [['pinned', 'DESC'], ['createdAt', 'DESC']], limit: 3, include: [{ model: User, as: 'author', attributes: ['id', 'fullName'] }] }),
    unreadNotifications: await Notification.count({ where: { userId: req.user.id, isRead: false } }),
  });
}));

router.get('/landlord', requireRole('landlord'), asyncHandler(async (req, res) => {
  const period = req.query.period || currentPeriod();
  if (!isPeriod(period)) return res.status(400).json({ message: 'period must be YYYY-MM' });
  res.json(await landlordSummary(period));
}));

module.exports = router;
