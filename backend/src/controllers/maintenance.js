const { MaintenanceReport } = require('../models');
const { include, createReport, updateReport } = require('../services/maintenance');

exports.create = async (req, res) => {
  const report = await createReport(req.user, {
    category: req.body.category,
    description: req.body.description,
    urgency: req.body.urgency,
    photoPath: req.file ? `/uploads/${req.file.filename}` : null,
  });
  res.status(201).json(report);
};

exports.mine = async (req, res) => {
  res.json(await MaintenanceReport.findAll({ where: { tenantId: req.user.id }, include, order: [['createdAt', 'DESC']] }));
};

exports.list = async (req, res) => {
  const where = {};
  if (req.query.roomId) where.roomId = req.query.roomId;
  if (req.query.status) where.status = req.query.status;
  res.json(await MaintenanceReport.findAll({ where, include, order: [['createdAt', 'DESC']] }));
};

exports.update = async (req, res) => {
  res.json(await updateReport(req.params.id, req.body));
};
