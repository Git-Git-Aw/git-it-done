const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const User = sequelize.define('User', {
  fullName: { type: DataTypes.STRING(120), allowNull: false, validate: { notEmpty: true } },
  email: { type: DataTypes.STRING(160), allowNull: false, unique: true, validate: { isEmail: true } },
  passwordHash: { type: DataTypes.STRING(100), allowNull: false },
  role: { type: DataTypes.ENUM('tenant', 'landlord'), allowNull: false, defaultValue: 'tenant' },
  contactNumber: { type: DataTypes.STRING(20) },
  status: { type: DataTypes.ENUM('pending', 'active', 'archived'), allowNull: false, defaultValue: 'pending' },
  resetTokenHash: { type: DataTypes.STRING(64) },
  resetExpires: { type: DataTypes.DATE },
}, { tableName: 'users' });

User.prototype.toJSON = function () {
  const v = { ...this.get() };
  delete v.passwordHash;
  delete v.resetTokenHash;
  delete v.resetExpires;
  return v;
};

module.exports = User;
