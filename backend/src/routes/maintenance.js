const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');
const ctrl = require('../controllers/maintenanceController');

router.use(auth);
router.post('/', requireRole('tenant'), upload.single('photo'), ctrl.create);
router.get('/mine', requireRole('tenant'), ctrl.listMine);
router.get('/', requireRole('landlord'), ctrl.list);
router.patch('/:id', requireRole('landlord'), ctrl.update);

module.exports = router;
