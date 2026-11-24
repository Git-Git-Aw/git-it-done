const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/dashboardController');

router.use(auth);
router.get('/tenant', requireRole('tenant'), ctrl.tenant);
router.get('/landlord', requireRole('landlord'), ctrl.landlord);

module.exports = router;
