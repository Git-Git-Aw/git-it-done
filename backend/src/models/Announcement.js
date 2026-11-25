const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Announcement = sequelize.define('Announcement', {
  authorId: { type: DataTypes.INTEGER, allowNull: false },
  title: { type: DataTypes.STRING(160), allowNull: false, validate: { notEmpty: true } },
  body: { type: DataTypes.TEXT, allowNull: false, validate: { notEmpty: true } },
  pinned: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  isArchived: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
}, { tableName: 'announcements' });

module.exports = Announcement;
