const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/maintenance');

router.use(auth);

// Tenant submits an issue (description, category, optional urgency, optional photo)
router.post('/', requireRole('tenant'), upload.single('photo'), asyncHandler(c.create));

router.get('/mine', requireRole('tenant'), asyncHandler(c.mine));

// Landlord: all reports, filter by room / status
router.get('/', requireRole('landlord'), asyncHandler(c.list));

// Landlord: update status / remarks / assignee
router.patch('/:id', requireRole('landlord'), asyncHandler(c.update));

module.exports = router;
