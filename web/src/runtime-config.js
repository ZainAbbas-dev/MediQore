// Base URL of the REST API. In development Vite forwards /api to the API server
// (vite.config.mjs); set VITE_API_BASE_URL for a build that talks to another host.
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';
