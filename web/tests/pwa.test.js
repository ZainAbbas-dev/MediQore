// P0-5: the portal is an installable web app with a service worker ready for
// web push (M10 FE-1, M5 FE-2).
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { registerServiceWorker } from '../src/pwa/register-service-worker';

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file));

// Width and height from a PNG's IHDR chunk.
function pngSize(file) {
  const bytes = read(path.join('public', file));
  expect(bytes.subarray(1, 4).toString('ascii')).toBe('PNG');
  return `${bytes.readUInt32BE(16)}x${bytes.readUInt32BE(20)}`;
}

// Runs public/sw.js against a fake service worker global and returns its listeners.
function loadServiceWorker() {
  const listeners = {};
  const self = {
    location: { origin: 'https://portal.example' },
    addEventListener: (type, fn) => {
      listeners[type] = fn;
    },
    skipWaiting: jest.fn(),
    registration: { showNotification: jest.fn(() => Promise.resolve()) },
    clients: { claim: jest.fn(() => Promise.resolve()), matchAll: jest.fn(), openWindow: jest.fn(() => Promise.resolve()) },
  };
  vm.runInNewContext(read('public/sw.js').toString(), { self, URL, console });
  return { self, listeners };
}

// A push or click event whose waitUntil promise the test can await.
function event(fields) {
  let pending = Promise.resolve();
  return {
    ...fields,
    waitUntil: (promise) => {
      pending = promise;
    },
    done: () => pending,
  };
}

describe('web app manifest', () => {
  const manifest = JSON.parse(read('public/manifest.webmanifest'));

  test('has what browsers need to offer installation', () => {
    expect(manifest).toMatchObject({ name: 'MediQore Portal', short_name: 'MediQore', start_url: '/', scope: '/', display: 'standalone' });
    expect(manifest.theme_color).toBe('#00695C');
  });

  test('lists 192 px, 512 px and maskable icons that exist with those sizes', () => {
    const bySize = (size, purpose) => manifest.icons.find((icon) => icon.sizes === size && icon.purpose === purpose);
    expect(bySize('192x192', 'any')).toBeTruthy();
    expect(bySize('512x512', 'any')).toBeTruthy();
    expect(bySize('512x512', 'maskable')).toBeTruthy();
    for (const icon of manifest.icons) {
      expect(icon.type).toBe('image/png');
      expect(pngSize(icon.src)).toBe(icon.sizes);
    }
    expect(pngSize('icons/apple-touch-icon.png')).toBe('180x180');
  });

  test('index.html links the manifest, theme colour and icons', () => {
    const html = read('index.html').toString();
    expect(html).toContain('<link rel="manifest" href="/manifest.webmanifest" />');
    expect(html).toContain('<meta name="theme-color" content="#00695C" />');
    expect(html).toContain('href="/icons/apple-touch-icon.png"');
    expect(fs.existsSync(path.join(root, 'public/icons/icon.svg'))).toBe(true);
  });
});

describe('service worker', () => {
  test('activates at once and caches nothing (no fetch handler: patient data never sits in browser storage)', async () => {
    const { self, listeners } = loadServiceWorker();
    expect(Object.keys(listeners).sort()).toEqual(['activate', 'install', 'notificationclick', 'push']);
    listeners.install(event({}));
    expect(self.skipWaiting).toHaveBeenCalled();
    const activate = event({});
    listeners.activate(activate);
    await activate.done();
    expect(self.clients.claim).toHaveBeenCalled();
  });

  test('shows a push message as a notification that stays until the supervisor acts', async () => {
    const { self, listeners } = loadServiceWorker();
    const push = event({ data: { json: () => ({ title: 'Emergency alert', body: 'SYN-0001: BP 170/112', url: '/alerts', tag: 'alert-1' }) } });
    listeners.push(push);
    await push.done();
    expect(self.registration.showNotification).toHaveBeenCalledWith('Emergency alert', expect.objectContaining({
      body: 'SYN-0001: BP 170/112',
      tag: 'alert-1',
      requireInteraction: true,
      data: { url: '/alerts' },
    }));
  });

  test('a push message that is not JSON, or has no data, still shows an alert', async () => {
    const { self, listeners } = loadServiceWorker();
    const text = event({ data: { json: () => { throw new SyntaxError('not json'); }, text: () => 'Check the portal' } });
    listeners.push(text);
    await text.done();
    expect(self.registration.showNotification).toHaveBeenLastCalledWith('MediQore alert', expect.objectContaining({ body: 'Check the portal' }));

    const empty = event({ data: null });
    listeners.push(empty);
    await empty.done();
    expect(self.registration.showNotification).toHaveBeenLastCalledWith('MediQore alert', expect.objectContaining({ data: { url: '/' } }));
  });

  test('a tap opens the alert page, or moves an open portal tab there', async () => {
    const { self, listeners } = loadServiceWorker();
    const notification = { close: jest.fn(), data: { url: '/alerts' } };

    self.clients.matchAll.mockResolvedValueOnce([]);
    const open = event({ notification });
    listeners.notificationclick(open);
    await open.done();
    expect(notification.close).toHaveBeenCalled();
    expect(self.clients.openWindow).toHaveBeenCalledWith('https://portal.example/alerts');

    const tab = { url: 'https://portal.example/women', focus: jest.fn(() => Promise.resolve()) };
    tab.navigate = jest.fn(() => Promise.resolve(tab));
    self.clients.matchAll.mockResolvedValueOnce([{ url: 'https://elsewhere.example/', navigate: jest.fn() }, tab]);
    const focus = event({ notification });
    listeners.notificationclick(focus);
    await focus.done();
    expect(tab.navigate).toHaveBeenCalledWith('https://portal.example/alerts');
    expect(tab.focus).toHaveBeenCalled();
  });
});

describe('registerServiceWorker', () => {
  test('does nothing outside a production build or without service worker support', async () => {
    const register = jest.fn();
    await expect(registerServiceWorker({ enabled: false, navigator: { serviceWorker: { register } } })).resolves.toBeNull();
    await expect(registerServiceWorker({ enabled: true, navigator: {} })).resolves.toBeNull();
    expect(register).not.toHaveBeenCalled();
  });

  test('registers /sw.js for the whole portal', async () => {
    const registration = { scope: '/' };
    const register = jest.fn(() => Promise.resolve(registration));
    await expect(registerServiceWorker({ enabled: true, navigator: { serviceWorker: { register } } })).resolves.toBe(registration);
    expect(register).toHaveBeenCalledWith('/sw.js', { scope: '/' });
  });

  test('a failed registration is reported, not thrown', async () => {
    const onError = jest.fn();
    const register = jest.fn(() => Promise.reject(new Error('blocked')));
    await expect(registerServiceWorker({ enabled: true, navigator: { serviceWorker: { register } }, onError })).resolves.toBeNull();
    expect(onError).toHaveBeenCalledWith(expect.objectContaining({ message: 'blocked' }));
  });
});
