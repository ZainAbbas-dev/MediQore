const AppError = require('../utils/app-error');

const PARTS = ['params', 'query', 'body'];

const JOI_OPTIONS = {
  abortEarly: false, // report every problem, not just the first
  stripUnknown: true, // drop fields the schema does not declare
  convert: true,
};

// Joi validation for a route, run before the controller and before any
// database call:
//
//   router.post('/things', validate({ body: thingSchema }), controller.create);
//
// Each validated part replaces the original on req, so controllers only ever
// see sanitised values. Fails with 400 VALIDATION_ERROR listing every problem.
function validate(schemas) {
  return (req, res, next) => {
    const details = [];
    const values = {};

    for (const part of PARTS) {
      if (!schemas[part]) continue;
      const { value, error } = schemas[part].validate(req[part] ?? {}, JOI_OPTIONS);
      if (error) {
        for (const item of error.details) {
          details.push({ in: part, path: item.path.join('.'), message: item.message });
        }
      } else {
        values[part] = value;
      }
    }

    if (details.length > 0) {
      return next(new AppError(400, 'VALIDATION_ERROR', 'Request validation failed', details));
    }

    for (const [part, value] of Object.entries(values)) {
      // Express 5 exposes req.query through a getter, so shadow it with an own property.
      Object.defineProperty(req, part, { value, writable: true, enumerable: true, configurable: true });
    }
    return next();
  };
}

module.exports = validate;
