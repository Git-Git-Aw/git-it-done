const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const DormInfo = sequelize.define('DormInfo', {
  dormName: { type: DataTypes.STRING(120) },
  address: { type: DataTypes.STRING(255) },
  contactNumber: { type: DataTypes.STRING(40) },
  about: { type: DataTypes.TEXT },
  houseRules: { type: DataTypes.TEXT },
  requirements: { type: DataTypes.TEXT },
}, { tableName: 'dorm_info' });

module.exports = DormInfo;
