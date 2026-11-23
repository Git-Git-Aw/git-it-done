const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/reports');

router.use(auth, requireRole('landlord'));

// Monthly payment summary: GET /api/reports/monthly?month=YYYY-MM&format=csv|json
router.get('/monthly', asyncHandler(c.monthly));

module.exports = router;
