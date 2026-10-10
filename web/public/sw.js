// M10 FE-1, M5 FE-2 (P0-5): service worker of the installable portal, ready for
// web push. Phase 2 subscribes supervisors through Firebase Cloud Messaging for
// web; the server's push message arrives here and is shown as a notification.
//
// It has no fetch handler and caches nothing: the portal shows patient data,
// which must never sit in the browser's storage, and it needs the API anyway.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// The notification for a push message. The payload is JSON
// { title, body, url, tag }; anything missing falls back to a generic alert,
// so a malformed message still reaches the supervisor.
function notificationFor(data) {
  let payload;
  try {
    payload = data ? data.json() : {};
  } catch {
    payload = { body: data.text() };
  }
  return {
    title: payload.title || 'MediQore alert',
    options: {
      body: payload.body || 'Open the portal to see the alert.',
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
      tag: payload.tag,
      requireInteraction: true,
      data: { url: payload.url || '/' },
    },
  };
}

self.addEventListener('push', (event) => {
  const { title, options } = notificationFor(event.data);
  event.waitUntil(self.registration.showNotification(title, options));
});

// Tapping the notification focuses an open portal tab on the alert's page, or opens one.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL(event.notification.data?.url || '/', self.location.origin).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      const open = windows.find((client) => new URL(client.url).origin === self.location.origin);
      if (open) return open.navigate(url).then((client) => (client || open).focus());
      return self.clients.openWindow(url);
    }),
  );
});
