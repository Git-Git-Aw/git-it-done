const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/reportsController');

router.use(auth, requireRole('landlord'));
router.get('/monthly', ctrl.monthly);

module.exports = router;
