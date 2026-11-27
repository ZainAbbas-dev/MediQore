// Base URL of the REST API. In development Vite forwards /api to the API server
// (vite.config.mjs); set VITE_API_BASE_URL for a build that talks to another host.
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';

// Firebase's public web settings. The service account stays in the API process.
export const FIREBASE_WEB_PUSH = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  vapidKey: import.meta.env.VITE_FIREBASE_VAPID_KEY,
};
