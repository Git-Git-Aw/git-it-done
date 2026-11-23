const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/dorminfoController');

router.get('/', ctrl.get);
router.put('/', auth, requireRole('landlord'), ctrl.update);

module.exports = router;
