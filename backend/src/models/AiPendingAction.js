const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

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

module.exports = AiPendingAction;
