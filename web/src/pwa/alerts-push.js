import { FIREBASE_WEB_PUSH } from '../runtime-config';

const STORAGE_KEY = 'mediqore.alertPush';
const APP_NAME = 'mediqore-alerts';

export function canEnableAlertPush() {
  return Boolean(
    FIREBASE_WEB_PUSH && Object.values(FIREBASE_WEB_PUSH).every(Boolean) &&
    globalThis.isSecureContext && navigator.serviceWorker && globalThis.Notification,
  );
}

export function alertPushRegistration(userId) {
  try {
    const registration = JSON.parse(localStorage.getItem(STORAGE_KEY));
    return registration?.userId === userId ? registration?.id : null;
  } catch {
    return null;
  }
}

async function firebaseMessaging() {
  const [{ getApps, initializeApp }, { getMessaging, getToken, deleteToken, isSupported }] = await Promise.all([
    import('@firebase/app'), import('@firebase/messaging'),
  ]);
  if (!(await isSupported())) throw new Error('This browser cannot receive web notifications.');
  const { vapidKey, ...appConfig } = FIREBASE_WEB_PUSH;
  const app = getApps().find(({ name }) => name === APP_NAME) ?? initializeApp(appConfig, APP_NAME);
  return { messaging: getMessaging(app), getToken, deleteToken, vapidKey };
}

export async function enableAlertPush(request, userId) {
  if (!canEnableAlertPush()) throw new Error('Web notifications are unavailable in this browser.');
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') throw new Error('Allow notifications in your browser settings to turn them on.');

  const { messaging, getToken, deleteToken, vapidKey } = await firebaseMessaging();
  await navigator.serviceWorker.register('/sw.js', { scope: '/' });
  const serviceWorkerRegistration = await navigator.serviceWorker.ready;
  const token = await getToken(messaging, { vapidKey, serviceWorkerRegistration });
  if (!token) throw new Error('Could not register this browser for notifications.');
  try {
    const { id } = await request('/alerts/push/subscriptions', { method: 'POST', body: { token } });
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ id, userId }));
    } catch {
      await request(`/alerts/push/subscriptions/${id}`, { method: 'DELETE' });
      throw new Error('Allow browser storage to finish enabling notifications.');
    }
    return id;
  } catch (error) {
    await deleteToken(messaging).catch(() => {});
    throw error;
  }
}

export async function disableAlertPush(request, userId) {
  const id = alertPushRegistration(userId);
  if (!id) return;
  await request(`/alerts/push/subscriptions/${id}`, { method: 'DELETE' });
  if (alertPushRegistration(userId) === id) localStorage.removeItem(STORAGE_KEY);
}
