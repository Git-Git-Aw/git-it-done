const { Announcement, User } = require('../models');
const { createAnnouncement } = require('../services/announcements');

const include = [{ model: User, as: 'author', attributes: ['id', 'fullName'] }];

// Tenants only see active announcements. A landlord can add ?archived=true to include archived ones.
exports.list = async (req, res) => {
  const showArchived = req.user.role === 'landlord' && req.query.archived === 'true';
  const where = showArchived ? {} : { isArchived: false };
  res.json(await Announcement.findAll({ where, include, order: [['pinned', 'DESC'], ['createdAt', 'DESC']] }));
};

exports.create = async (req, res) => {
  res.status(201).json(await createAnnouncement(req.user, req.body));
};

exports.update = async (req, res) => {
  const a = await Announcement.findByPk(req.params.id);
  if (!a) return res.status(404).json({ message: 'Announcement not found' });
  const { title, body, pinned } = req.body;
  await a.update({ title, body, pinned });
  res.json(await Announcement.findByPk(a.id, { include }));
};

// No hard delete: archiving hides the announcement but keeps the record (restore brings it back).
exports.archive = async (req, res) => {
  const a = await Announcement.findByPk(req.params.id);
  if (!a) return res.status(404).json({ message: 'Announcement not found' });
  await a.update({ isArchived: true });
  res.json(await Announcement.findByPk(a.id, { include }));
};

exports.restore = async (req, res) => {
  const a = await Announcement.findByPk(req.params.id);
  if (!a) return res.status(404).json({ message: 'Announcement not found' });
  await a.update({ isArchived: false });
  res.json(await Announcement.findByPk(a.id, { include }));
};