const router = require('express').Router();
const { Op } = require('sequelize');
const { Notification, Payment } = require('../models');
const { auth } = require('../middleware/auth');
const { asyncHandler, todayStr } = require('../utils/helpers');
const { notify } = require('../utils/notify');

router.use(auth);

// In-app reminders (no SMS/email): create one reminder per upcoming/overdue bill, once.
const ensureDueReminders = async (user) => {
  if (user.role !== 'tenant') return;
  const soon = new Date(Date.now() + 3 * 86400000);
  const soonStr = `${soon.getFullYear()}-${String(soon.getMonth() + 1).padStart(2, '0')}-${String(soon.getDate()).padStart(2, '0')}`;
  const bills = await Payment.findAll({ where: { tenantId: user.id, status: 'unpaid', dueDate: { [Op.lte]: soonStr } } });
  for (const b of bills) {
    const type = b.dueDate < todayStr() ? 'overdue_reminder' : 'due_reminder';
    const exists = await Notification.count({ where: { userId: user.id, type, refType: 'payment', refId: b.id } });
    if (!exists) {
      await notify(user.id, type, type === 'overdue_reminder'
        ? `Your payment for ${b.period} is overdue (was due ${b.dueDate}).`
        : `Your payment for ${b.period} is due on ${b.dueDate}.`, 'payment', b.id);
    }
  }
};

router.get('/', asyncHandler(async (req, res) => {
  await ensureDueReminders(req.user);
  const where = { userId: req.user.id };
  if (req.query.unread === 'true') where.isRead = false;
  const items = await Notification.findAll({ where, order: [['createdAt', 'DESC']], limit: 100 });
  res.json({ unread: items.filter((n) => !n.isRead).length, items });
}));

router.patch('/read-all', asyncHandler(async (req, res) => {
  await Notification.update({ isRead: true }, { where: { userId: req.user.id, isRead: false } });
  res.json({ message: 'All notifications marked as read' });
}));

router.patch('/:id/read', asyncHandler(async (req, res) => {
  const n = await Notification.findOne({ where: { id: req.params.id, userId: req.user.id } });
  if (!n) return res.status(404).json({ message: 'Notification not found' });
  await n.update({ isRead: true });
  res.json(n);
}));

module.exports = router;
