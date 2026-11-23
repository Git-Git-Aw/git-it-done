const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/dorminfo');

// Public: visitors (and the AI chatbox) read the dormitory's public information
router.get('/', asyncHandler(c.get));

// Landlord edits it (single row, created on first save)
router.put('/', auth, requireRole('landlord'), asyncHandler(c.update));

module.exports = router;