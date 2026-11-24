const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/leasesController');

router.use(auth, requireRole('landlord'));
router.get('/', ctrl.list);
router.post('/', ctrl.create);
router.put('/:id', ctrl.update);
router.patch('/:id/end', ctrl.end);

module.exports = router;
