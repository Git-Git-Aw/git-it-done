const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const { money } = require('./fields');

const Room = sequelize.define('Room', {
  roomNumber: { type: DataTypes.STRING(20), allowNull: false, unique: true, validate: { notEmpty: true } },
  description: { type: DataTypes.STRING(255) },
  monthlyRate: money('monthlyRate'),
  capacity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1, validate: { min: 1 } },
  isArchived: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'rooms' });

module.exports = Room;
