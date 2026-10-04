const { Router } = require('express');
const healthRoutes = require('./health.routes');
const authRoutes = require('./auth.routes');
const syncRoutes = require('./sync.routes');
const householdsRoutes = require('./households.routes');
const adminRoutes = require('./admin.routes');
const devicesRoutes = require('./devices.routes');
const womenRoutes = require('./women.routes');
const conflictsRoutes = require('./conflicts.routes');
const dashboardRoutes = require('./dashboard.routes');

// Everything here is mounted under /api/v1 (see app.js). Each feature adds its
// own <name>.routes.js and mounts it below; document every route in
// docs/openapi.yaml in the same pull request.
const router = Router();

router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/sync', syncRoutes);
router.use('/households', householdsRoutes);
router.use('/admin', adminRoutes);
router.use('/devices', devicesRoutes);
router.use('/women', womenRoutes);
router.use('/conflicts', conflictsRoutes);
router.use('/dashboard', dashboardRoutes);

module.exports = router;
