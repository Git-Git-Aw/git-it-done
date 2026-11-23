const { VisitorInquiry } = require('../models');

exports.list = async (req, res) => {
  const where = {};
  if (req.query.status) where.status = req.query.status;
  res.json(await VisitorInquiry.findAll({ where, order: [['createdAt', 'DESC']] }));
};

exports.update = async (req, res) => {
  const q = await VisitorInquiry.findByPk(req.params.id);
  if (!q) return res.status(404).json({ message: 'Inquiry not found' });
  if (!['new', 'contacted'].includes(req.body.status)) return res.status(400).json({ message: 'status must be "new" or "contacted"' });
  res.json(await q.update({ status: req.body.status }));
};