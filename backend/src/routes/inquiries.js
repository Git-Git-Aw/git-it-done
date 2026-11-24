const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/inquiriesController');

router.use(auth, requireRole('landlord'));
router.get('/', ctrl.list);
router.patch('/:id', ctrl.update);

module.exports = router;
