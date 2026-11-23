const router = require('express').Router();
const { auth, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');
const ctrl = require('../controllers/paymentsController');

router.use(auth);
/* ---------- Tenant ---------- */
router.get('/mine', requireRole('tenant'), ctrl.listMine);
router.post('/:id/proof', requireRole('tenant'), upload.single('proof'), ctrl.uploadProof);
/* ---------- Landlord ---------- */
router.get('/', requireRole('landlord'), ctrl.list);
router.post('/generate', requireRole('landlord'), ctrl.generate);
router.patch('/:id/record', requireRole('landlord'), ctrl.record);
router.patch('/:id/confirm', requireRole('landlord'), ctrl.confirm);
router.patch('/:id/reject', requireRole('landlord'), ctrl.reject);

module.exports = router;
