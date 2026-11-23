const { DormInfo } = require('../models');

// Public: visitors (and the AI chatbox) read the dormitory's public information
exports.get = async (req, res) => {
  const info = await DormInfo.findOne({ order: [['id', 'ASC']] });
  res.json(info || { dormName: null, address: null, contactNumber: null, about: null, houseRules: null, requirements: null });
};

// Landlord edits it (single row, created on first save)
exports.update = async (req, res) => {
  const { dormName, address, contactNumber, about, houseRules, requirements } = req.body;
  const data = { dormName, address, contactNumber, about, houseRules, requirements };
  const info = await DormInfo.findOne({ order: [['id', 'ASC']] });
  res.json(info ? await info.update(data) : await DormInfo.create(data));
};