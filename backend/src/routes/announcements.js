const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/announcements');

router.use(auth);

router.get('/', asyncHandler(c.list));
router.post('/', requireRole('landlord'), asyncHandler(c.create));
router.put('/:id', requireRole('landlord'), asyncHandler(c.update));
router.patch('/:id/archive', requireRole('landlord'), asyncHandler(c.archive));
router.patch('/:id/restore', requireRole('landlord'), asyncHandler(c.restore));

module.exports = router;