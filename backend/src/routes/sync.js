const router = require('express').Router();
const { auth } = require('../middleware/auth');
const ctrl = require('../controllers/syncController');

router.use(auth);
router.get('/', ctrl.sync);

module.exports = router;
