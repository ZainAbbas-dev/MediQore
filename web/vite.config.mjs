import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// In development the portal calls /api/v1 on its own origin and Vite forwards
// it to the API, so the browser needs no CORS. Point the proxy elsewhere with
// API_PROXY_TARGET (environment or web/.env) if the API is not on localhost:3000.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        '/api': env.API_PROXY_TARGET || 'http://localhost:3000',
      },
    },
  };
});
