const { MaintenanceReport } = require('../models');
const { asyncHandler } = require('../utils/helpers');
const { include, createReport, updateReport } = require('../services/maintenance');

// Tenant submits an issue (description, category, optional urgency, optional photo)
const create = asyncHandler(async (req, res) => {
  const report = await createReport(req.user, {
    category: req.body.category,
    description: req.body.description,
    urgency: req.body.urgency,
    photoPath: req.file ? `/uploads/${req.file.filename}` : null,
  });
  res.status(201).json(report);
});

const listMine = asyncHandler(async (req, res) => {
  res.json(await MaintenanceReport.findAll({ where: { tenantId: req.user.id }, include, order: [['createdAt', 'DESC']] }));
});

// Landlord: all reports, filter by room / status
const list = asyncHandler(async (req, res) => {
  const where = {};
  if (req.query.roomId) where.roomId = req.query.roomId;
  if (req.query.status) where.status = req.query.status;
  res.json(await MaintenanceReport.findAll({ where, include, order: [['createdAt', 'DESC']] }));
});

// Landlord: update status / remarks / assignee
const update = asyncHandler(async (req, res) => {
  res.json(await updateReport(req.params.id, req.body));
});

module.exports = { create, listMine, list, update };
