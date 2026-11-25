const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const VisitorInquiry = sequelize.define('VisitorInquiry', {
  name: { type: DataTypes.STRING(120), allowNull: false, validate: { notEmpty: true } },
  contactNumber: { type: DataTypes.STRING(40), allowNull: false, validate: { notEmpty: true } },
  message: { type: DataTypes.TEXT },
  status: { type: DataTypes.ENUM('new', 'contacted'), allowNull: false, defaultValue: 'new' },
}, { tableName: 'visitor_inquiries' });

module.exports = VisitorInquiry;
