// M10 FE-1 (Phase 1 base): dashboard counts for supervisors and admins.
const { Router } = require('express');
const { authenticate, requireRole } = require('../middleware/auth');
const dashboardController = require('../controllers/dashboard.controller');

const router = Router();

router.get('/summary', authenticate, requireRole('supervisor', 'admin'), dashboardController.summary);

module.exports = router;
