const router = require('express').Router();
const { auth } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const c = require('../controllers/sync');

router.use(auth);

// GET /api/sync?since=<ISO timestamp>  -> everything the caller can see that changed after "since"
router.get('/', asyncHandler(c.changes));

module.exports = router;
