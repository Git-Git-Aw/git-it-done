const router = require('express').Router();

// One line per module: URL prefix (under /api) and its route file
router.use('/auth', require('./auth'));
router.use('/tenants', require('./tenants'));
router.use('/rooms', require('./rooms'));
router.use('/leases', require('./leases'));
router.use('/payments', require('./payments'));
router.use('/maintenance', require('./maintenance'));
router.use('/announcements', require('./announcements'));
router.use('/notifications', require('./notifications'));
router.use('/dashboard', require('./dashboard'));
router.use('/reports', require('./reports'));
router.use('/sync', require('./sync'));
router.use('/dorm-info', require('./dorminfo'));
router.use('/inquiries', require('./inquiries'));
router.use('/chat', require('./chat'));

module.exports = router;
