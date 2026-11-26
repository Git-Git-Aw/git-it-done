const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const { money } = require('./fields');

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

module.exports = Payment;
