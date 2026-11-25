const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

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

module.exports = MaintenanceReport;
