const { DataTypes } = require('sequelize');

const money = (field) => ({
  type: DataTypes.DECIMAL(10, 2),
  allowNull: false,
  defaultValue: 0,
  get() { return Number(this.getDataValue(field)); },
});

module.exports = { money };
