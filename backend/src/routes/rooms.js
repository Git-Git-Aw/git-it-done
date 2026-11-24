const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/roomsController');

router.use(auth, requireRole('landlord'));
router.get('/', ctrl.list);
router.get('/:id', ctrl.get);
router.post('/', ctrl.create);
router.put('/:id', ctrl.update);
router.patch('/:id/archive', ctrl.archive);
router.patch('/:id/restore', ctrl.restore);

module.exports = router;
