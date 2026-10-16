// Times on the portal, in the viewer's local time: "Today 10:31",
// "Yesterday 17:40", "4 days ago", or a date such as "6 Oct" (final design
// screen 20). Server times only, never used to order records (LI-7).
const DAY_MS = 24 * 60 * 60 * 1000;

// An LHW whose last sync is this many days old or more is highlighted on the
// dashboard. A display hint only; inactivity detection by visit history is
// M10 FE-4 (Phase 2).
export const STALE_AFTER_DAYS = 2;

const startOfDay = (date) => new Date(date.getFullYear(), date.getMonth(), date.getDate());

export const clock = (date) => new Date(date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

export function formatWhen(value, now = new Date(), { withTime = true } = {}) {
  if (!value) return null;
  const date = new Date(value);
  const days = Math.round((startOfDay(now) - startOfDay(date)) / DAY_MS);
  if (days <= 0) return withTime ? `Today ${clock(date)}` : 'Today';
  if (days === 1) return withTime ? `Yesterday ${clock(date)}` : 'Yesterday';
  if (days < 7) return `${days} days ago`;
  const sameYear = date.getFullYear() === now.getFullYear();
  return date.toLocaleDateString([], { day: 'numeric', month: 'short', ...(sameYear ? {} : { year: 'numeric' }) });
}

export function isStale(lastSyncAt, now = new Date()) {
  return !lastSyncAt || now - new Date(lastSyncAt) >= STALE_AFTER_DAYS * DAY_MS;
}
