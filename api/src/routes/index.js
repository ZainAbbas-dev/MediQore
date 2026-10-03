const { Router } = require('express');
const healthRoutes = require('./health.routes');

// Everything here is mounted under /api/v1 (see app.js). Each feature adds its
// own <name>.routes.js and mounts it below; document every route in
// docs/openapi.yaml in the same pull request.
const router = Router();

router.use('/health', healthRoutes);

module.exports = router;
