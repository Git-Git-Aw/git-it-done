const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Notification = sequelize.define('Notification', {
  userId: { type: DataTypes.INTEGER, allowNull: false },
  type: { type: DataTypes.STRING(40), allowNull: false },
  message: { type: DataTypes.STRING(255), allowNull: false },
  refType: { type: DataTypes.STRING(30) },
  refId: { type: DataTypes.INTEGER },
  isRead: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'notifications' });

module.exports = Notification;
