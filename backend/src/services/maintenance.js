const { MaintenanceReport, Lease, Room, User } = require('../models');
const { httpError } = require('../utils/helpers');
const { notify, notifyLandlords } = require('../utils/notify');

const CATEGORIES = ['plumbing', 'electrical', 'furniture', 'appliance', 'cleaning', 'other'];
const URGENCIES = ['low', 'medium', 'high'];
const STATUSES = ['Pending', 'In Progress', 'Resolved'];

const include = [
  { model: Room, as: 'room', attributes: ['id', 'roomNumber'] },
  { model: User, as: 'tenant', attributes: ['id', 'fullName', 'contactNumber'] },
];

// Tenant files a report (used by the form screen and by the AI chatbox)
const createReport = async (user, { category, description, urgency, photoPath }) => {
  const text = String(description || '').trim();
  if (!text) throw httpError(400, 'description is required');
  const lease = await Lease.findOne({ where: { tenantId: user.id, status: 'active' }, include: [{ model: Room, as: 'room' }] });
  if (!lease) throw httpError(409, 'You need an active room assignment to submit a report');
  const cat = CATEGORIES.includes(category) ? category : 'other';
  const urg = URGENCIES.includes(urgency) ? urgency : 'medium';
  const report = await MaintenanceReport.create({
    tenantId: user.id, roomId: lease.roomId, category: cat, urgency: urg, description: text, photoPath: photoPath || null,
  });
  await notifyLandlords('maintenance', `New ${urg === 'high' ? 'URGENT ' : ''}${cat} issue reported in Room ${lease.room.roomNumber}.`, 'maintenance', report.id);
  return MaintenanceReport.findByPk(report.id, { include });
};

// Landlord updates status / remarks / assignee
const updateReport = async (id, { status, remarks, assignedTo }) => {
  const r = await MaintenanceReport.findByPk(id);
  if (!r) throw httpError(404, 'Report not found');
  if (status && !STATUSES.includes(status)) throw httpError(400, `status must be one of: ${STATUSES.join(', ')}`);
  await r.update({
    status: status || r.status,
    remarks: remarks ?? r.remarks,
    assignedTo: assignedTo ?? r.assignedTo,
    resolvedAt: status === 'Resolved' ? new Date() : status ? null : r.resolvedAt,
  });
  if (status) await notify(r.tenantId, 'maintenance', `Your ${r.category} report is now "${r.status}".`, 'maintenance', r.id);
  return MaintenanceReport.findByPk(r.id, { include });
};

module.exports = { CATEGORIES, URGENCIES, STATUSES, include, createReport, updateReport };
