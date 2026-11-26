const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const { money } = require('./fields');

const Lease = sequelize.define('Lease', {
  tenantId: { type: DataTypes.INTEGER, allowNull: false },
  roomId: { type: DataTypes.INTEGER, allowNull: false },
  startDate: { type: DataTypes.DATEONLY, allowNull: false },
  endDate: { type: DataTypes.DATEONLY },
  monthlyRent: money('monthlyRent'),
  dueDay: { type: DataTypes.TINYINT, allowNull: false, defaultValue: 5, validate: { min: 1, max: 28 } },
  status: { type: DataTypes.ENUM('active', 'ended'), allowNull: false, defaultValue: 'active' },
}, { tableName: 'leases' });

module.exports = Lease;
