const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/dashboard');

router.use(auth);

router.get('/tenant', requireRole('tenant'), asyncHandler(c.tenant));
router.get('/landlord', requireRole('landlord'), asyncHandler(c.landlord));

module.exports = router;
