const sequelize = require('../config/db');

const User = require('./User');
const Room = require('./Room');
const Lease = require('./Lease');
const Payment = require('./Payment');
const MaintenanceReport = require('./MaintenanceReport');
const Announcement = require('./Announcement');
const Notification = require('./Notification');
const DormInfo = require('./DormInfo');
const VisitorInquiry = require('./VisitorInquiry');
const AiPendingAction = require('./AiPendingAction');
const Category = require('./Category');

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

module.exports = { sequelize, User, Room, Lease, Payment, MaintenanceReport, Announcement, Notification, DormInfo, VisitorInquiry, AiPendingAction, Category };
