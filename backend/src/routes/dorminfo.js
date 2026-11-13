const router = require('express').Router();
const { DormInfo } = require('../models');
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');

// Public: visitors (and the AI chatbox) read the dormitory's public information
router.get('/', asyncHandler(async (req, res) => {
  const info = await DormInfo.findOne({ order: [['id', 'ASC']] });
  res.json(info || { dormName: null, address: null, contactNumber: null, about: null, houseRules: null, requirements: null });
}));

// Landlord edits it (single row, created on first save)
router.put('/', auth, requireRole('landlord'), asyncHandler(async (req, res) => {
  const { dormName, address, contactNumber, about, houseRules, requirements } = req.body;
  const data = { dormName, address, contactNumber, about, houseRules, requirements };
  const info = await DormInfo.findOne({ order: [['id', 'ASC']] });
  res.json(info ? await info.update(data) : await DormInfo.create(data));
}));

module.exports = router;
