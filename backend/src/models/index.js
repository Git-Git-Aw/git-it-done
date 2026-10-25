const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const money = (field) => ({
  type: DataTypes.DECIMAL(10, 2),
  allowNull: false,
  defaultValue: 0,
  get() { return Number(this.getDataValue(field)); },
});

const User = sequelize.define('User', {
  fullName: { type: DataTypes.STRING(120), allowNull: false, validate: { notEmpty: true } },
  email: { type: DataTypes.STRING(160), allowNull: false, unique: true, validate: { isEmail: true } },
  passwordHash: { type: DataTypes.STRING(100), allowNull: false },
  role: { type: DataTypes.ENUM('tenant', 'landlord'), allowNull: false, defaultValue: 'tenant' },
  contactNumber: { type: DataTypes.STRING(20) },
  status: { type: DataTypes.ENUM('pending', 'active', 'archived'), allowNull: false, defaultValue: 'pending' },
  resetTokenHash: { type: DataTypes.STRING(64) },
  resetExpires: { type: DataTypes.DATE },
}, { tableName: 'users' });

User.prototype.toJSON = function () {
  const v = { ...this.get() };
  delete v.passwordHash;
  delete v.resetTokenHash;
  delete v.resetExpires;
  return v;
};

const Room = sequelize.define('Room', {
  roomNumber: { type: DataTypes.STRING(20), allowNull: false, unique: true, validate: { notEmpty: true } },
  description: { type: DataTypes.STRING(255) },
  monthlyRate: money('monthlyRate'),
  capacity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1, validate: { min: 1 } },
  isArchived: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'rooms' });

const Lease = sequelize.define('Lease', {
  tenantId: { type: DataTypes.INTEGER, allowNull: false },
  roomId: { type: DataTypes.INTEGER, allowNull: false },
  startDate: { type: DataTypes.DATEONLY, allowNull: false },
  endDate: { type: DataTypes.DATEONLY },
  monthlyRent: money('monthlyRent'),
  dueDay: { type: DataTypes.TINYINT, allowNull: false, defaultValue: 5, validate: { min: 1, max: 28 } },
  status: { type: DataTypes.ENUM('active', 'ended'), allowNull: false, defaultValue: 'active' },
}, { tableName: 'leases' });

const Payment = sequelize.define('Payment', {
  leaseId: { type: DataTypes.INTEGER, allowNull: false },
  tenantId: { type: DataTypes.INTEGER, allowNull: false },
  period: { type: DataTypes.CHAR(7), allowNull: false },
  dueDate: { type: DataTypes.DATEONLY, allowNull: false },
  amountDue: money('amountDue'),
  amountPaid: money('amountPaid'),
  status: { type: DataTypes.ENUM('unpaid', 'pending_confirmation', 'paid'), allowNull: false, defaultValue: 'unpaid' },
  method: { type: DataTypes.STRING(30) },
  proofPath: { type: DataTypes.STRING(255) },
  paidAt: { type: DataTypes.DATE },
  remarks: { type: DataTypes.STRING(255) },
}, { tableName: 'payments', indexes: [{ unique: true, fields: ['lease_id', 'period'] }] });

const MaintenanceReport = sequelize.define('MaintenanceReport', {
  tenantId: { type: DataTypes.INTEGER, allowNull: false },
  roomId: { type: DataTypes.INTEGER, allowNull: false },
  category: { type: DataTypes.ENUM('plumbing', 'electrical', 'furniture', 'appliance', 'cleaning', 'other'), allowNull: false, defaultValue: 'other' },
  urgency: { type: DataTypes.ENUM('low', 'medium', 'high'), allowNull: false, defaultValue: 'medium' },
  description: { type: DataTypes.TEXT, allowNull: false, validate: { notEmpty: true } },
  photoPath: { type: DataTypes.STRING(255) },
  status: { type: DataTypes.ENUM('Pending', 'In Progress', 'Resolved'), allowNull: false, defaultValue: 'Pending' },
  remarks: { type: DataTypes.STRING(500) },
  assignedTo: { type: DataTypes.STRING(120) },
  resolvedAt: { type: DataTypes.DATE },
}, { tableName: 'maintenance_reports' });

const Announcement = sequelize.define('Announcement', {
  authorId: { type: DataTypes.INTEGER, allowNull: false },
  title: { type: DataTypes.STRING(160), allowNull: false, validate: { notEmpty: true } },
  body: { type: DataTypes.TEXT, allowNull: false, validate: { notEmpty: true } },
  pinned: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  isArchived: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'announcements' });

const Notification = sequelize.define('Notification', {
  userId: { type: DataTypes.INTEGER, allowNull: false },
  type: { type: DataTypes.STRING(40), allowNull: false },
  message: { type: DataTypes.STRING(255), allowNull: false },
  refType: { type: DataTypes.STRING(30) },
  refId: { type: DataTypes.INTEGER },
  isRead: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'notifications' });

const DormInfo = sequelize.define('DormInfo', {
  dormName: { type: DataTypes.STRING(120) },
  address: { type: DataTypes.STRING(255) },
  contactNumber: { type: DataTypes.STRING(40) },
  about: { type: DataTypes.TEXT },
  houseRules: { type: DataTypes.TEXT },
  requirements: { type: DataTypes.TEXT },
}, { tableName: 'dorm_info' });

const VisitorInquiry = sequelize.define('VisitorInquiry', {
  name: { type: DataTypes.STRING(120), allowNull: false, validate: { notEmpty: true } },
  contactNumber: { type: DataTypes.STRING(40), allowNull: false, validate: { notEmpty: true } },
  message: { type: DataTypes.TEXT },
  status: { type: DataTypes.ENUM('new', 'contacted'), allowNull: false, defaultValue: 'new' },
}, { tableName: 'visitor_inquiries' });

// Every data-changing action the AI proposes is stored here and only runs after the user confirms it.
const AiPendingAction = sequelize.define('AiPendingAction', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  userId: { type: DataTypes.INTEGER, allowNull: true },
  role: { type: DataTypes.ENUM('landlord', 'tenant', 'visitor'), allowNull: false },
  toolName: { type: DataTypes.STRING(60), allowNull: false },
  input: { type: DataTypes.TEXT, allowNull: false },
  summary: { type: DataTypes.STRING(500), allowNull: false },
  status: { type: DataTypes.ENUM('pending', 'executed', 'cancelled', 'failed'), allowNull: false, defaultValue: 'pending' },
  result: { type: DataTypes.TEXT },
  expiresAt: { type: DataTypes.DATE, allowNull: false },
}, { tableName: 'ai_pending_actions' });

// Associations
User.hasMany(Lease, { as: 'leases', foreignKey: 'tenantId' });
Lease.belongsTo(User, { as: 'tenant', foreignKey: 'tenantId' });
Room.hasMany(Lease, { as: 'leases', foreignKey: 'roomId' });
Lease.belongsTo(Room, { as: 'room', foreignKey: 'roomId' });
Lease.hasMany(Payment, { as: 'payments', foreignKey: 'leaseId' });
Payment.belongsTo(Lease, { as: 'lease', foreignKey: 'leaseId' });
Payment.belongsTo(User, { as: 'tenant', foreignKey: 'tenantId' });
MaintenanceReport.belongsTo(User, { as: 'tenant', foreignKey: 'tenantId' });
MaintenanceReport.belongsTo(Room, { as: 'room', foreignKey: 'roomId' });
Room.hasMany(MaintenanceReport, { as: 'reports', foreignKey: 'roomId' });
Announcement.belongsTo(User, { as: 'author', foreignKey: 'authorId' });
Notification.belongsTo(User, { as: 'user', foreignKey: 'userId' });

module.exports = { sequelize, User, Room, Lease, Payment, MaintenanceReport, Announcement, Notification, DormInfo, VisitorInquiry, AiPendingAction };
