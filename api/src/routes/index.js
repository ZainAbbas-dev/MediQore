const { Router } = require('express');
const healthRoutes = require('./health.routes');
const authRoutes = require('./auth.routes');
const syncRoutes = require('./sync.routes');
const householdsRoutes = require('./households.routes');

// Everything here is mounted under /api/v1 (see app.js). Each feature adds its
// own <name>.routes.js and mounts it below; document every route in
// docs/openapi.yaml in the same pull request.
const router = Router();

router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/sync', syncRoutes);
router.use('/households', householdsRoutes);

module.exports = router;
