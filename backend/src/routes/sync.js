const router = require('express').Router();
const { Op } = require('sequelize');
const { Payment, MaintenanceReport, Announcement, Notification, Lease, Room, User } = require('../models');
const { auth } = require('../middleware/auth');
const { asyncHandler, presentPayment } = require('../utils/helpers');

router.use(auth);

// GET /api/sync?since=<ISO timestamp>  -> everything the caller can see that changed after "since"
router.get('/', asyncHandler(async (req, res) => {
  const since = req.query.since ? new Date(req.query.since) : new Date(0);
  if (Number.isNaN(since.getTime())) return res.status(400).json({ message: 'since must be an ISO timestamp' });
  const serverTime = new Date().toISOString();
  const changed = { updatedAt: { [Op.gt]: since } };
  const mine = req.user.role === 'tenant' ? { tenantId: req.user.id } : {};

  const payload = {
    serverTime,
    payments: (await Payment.findAll({ where: { ...changed, ...mine } })).map(presentPayment),
    maintenance: await MaintenanceReport.findAll({ where: { ...changed, ...mine } }),
    announcements: await Announcement.findAll({ where: changed }),
    notifications: await Notification.findAll({ where: { ...changed, userId: req.user.id } }),
  };
  if (req.user.role === 'tenant') {
    payload.leases = await Lease.findAll({ where: { ...changed, tenantId: req.user.id }, include: [{ model: Room, as: 'room' }] });
  } else {
    payload.rooms = await Room.findAll({ where: changed });
    payload.leases = await Lease.findAll({ where: changed });
    payload.tenants = await User.findAll({ where: { ...changed, role: 'tenant' } });
  }
  res.json(payload);
}));

module.exports = router;
