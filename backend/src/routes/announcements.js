const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const ctrl = require('../controllers/announcementsController');

router.use(auth);
router.get('/', ctrl.list);
router.post('/', requireRole('landlord'), ctrl.create);
router.put('/:id', requireRole('landlord'), ctrl.update);
router.patch('/:id/archive', requireRole('landlord'), ctrl.archive);
router.patch('/:id/restore', requireRole('landlord'), ctrl.restore);

module.exports = router;
