const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Category = sequelize.define('Category', {
  name: { type: DataTypes.STRING(60), allowNull: false, unique: true, validate: { notEmpty: true } },
}, { tableName: 'categories' });

module.exports = Category;
