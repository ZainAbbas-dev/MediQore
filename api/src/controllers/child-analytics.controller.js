const analytics = require('../services/child-analytics.service');

function read(operation) {
  return async (req, res) => res.json(await operation(req.user, req.query));
}

module.exports = {
  filters: read(analytics.filters),
  children: read(analytics.children),
  coverage: read(analytics.coverage),
  polio: read(analytics.polio),
  hotspots: read(analytics.hotspots),
};
