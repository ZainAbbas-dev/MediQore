// P0-5: registers the portal's service worker (public/sw.js), which makes the
// portal installable and ready for web push (M10 FE-1). Only production builds
// register it, so the development server never runs a stale worker.
export function registerServiceWorker({ enabled, navigator: nav = globalThis.navigator, onError = console.error } = {}) {
  if (!enabled || !nav || !('serviceWorker' in nav)) return Promise.resolve(null);
  return nav.serviceWorker.register('/sw.js', { scope: '/' }).catch((error) => {
    onError(error);
    return null;
  });
}
