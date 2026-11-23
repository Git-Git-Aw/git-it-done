const router = require('express').Router();
const { auth } = require('../middleware/auth');
const ctrl = require('../controllers/notificationsController');

router.use(auth);
router.get('/', ctrl.list);
router.patch('/read-all', ctrl.readAll);
router.patch('/:id/read', ctrl.markRead);

module.exports = router;
