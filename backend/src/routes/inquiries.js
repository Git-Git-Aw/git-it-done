const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/inquiries');

router.use(auth, requireRole('landlord'));

router.get('/', asyncHandler(c.list));
router.patch('/:id', asyncHandler(c.update));

module.exports = router;
