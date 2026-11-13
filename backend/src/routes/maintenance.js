const router = require('express').Router();
const { MaintenanceReport } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');
const { asyncHandler } = require('../utils/helpers');
const { include, createReport, updateReport } = require('../services/maintenance');

router.use(auth);

// Tenant submits an issue (description, category, optional urgency, optional photo)
router.post('/', requireRole('tenant'), upload.single('photo'), asyncHandler(async (req, res) => {
  const report = await createReport(req.user, {
    category: req.body.category,
    description: req.body.description,
    urgency: req.body.urgency,
    photoPath: req.file ? `/uploads/${req.file.filename}` : null,
  });
  res.status(201).json(report);
}));

router.get('/mine', requireRole('tenant'), asyncHandler(async (req, res) => {
  res.json(await MaintenanceReport.findAll({ where: { tenantId: req.user.id }, include, order: [['createdAt', 'DESC']] }));
}));

// Landlord: all reports, filter by room / status
router.get('/', requireRole('landlord'), asyncHandler(async (req, res) => {
  const where = {};
  if (req.query.roomId) where.roomId = req.query.roomId;
  if (req.query.status) where.status = req.query.status;
  res.json(await MaintenanceReport.findAll({ where, include, order: [['createdAt', 'DESC']] }));
}));

// Landlord: update status / remarks / assignee
router.patch('/:id', requireRole('landlord'), asyncHandler(async (req, res) => {
  res.json(await updateReport(req.params.id, req.body));
}));

module.exports = router;
