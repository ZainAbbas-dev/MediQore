import { fireEvent, screen } from '@testing-library/react';
import { renderApp, supervisorSession } from './helpers';

const areaId = 'd1396830-753a-4119-9c61-e292b95a7675';
const report = {
  areaId, areaName: 'Village North', districtName: 'Synthetic District', period: 'weekly',
  periodStart: '2026-05-25', periodEnd: '2026-05-31',
  files: {
    pdf: { id: 'pdf-job', status: 'done', available: true, generatedAt: '2026-05-31T19:05:00Z' },
    xlsx: { id: 'xlsx-job', status: 'queued', available: false, generatedAt: null },
  },
};

const json = (status, value) => ({ ok: status < 400, status, text: async () => JSON.stringify(value) });

it('shows Pakistan-time reporting periods and downloads a ready file through authenticated fetch', async () => {
  const user = { ...supervisorSession.user, permissions: ['reports.view'] };
  const session = { ...supervisorSession, user };
  const file = new Blob(['synthetic PDF'], { type: 'application/pdf' });
  const create = jest.fn(() => 'blob:synthetic-report');
  const revoke = jest.fn();
  const originals = [URL.createObjectURL, URL.revokeObjectURL];
  URL.createObjectURL = create;
  URL.revokeObjectURL = revoke;
  jest.useFakeTimers();
  const download = jest.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});

  globalThis.fetch = jest.fn(async (url, options) => {
    if (url.endsWith('/reports/pdf-job/download')) {
      if (options.headers.Authorization === 'Bearer token-1') return json(401, { error: { code: 'TOKEN_EXPIRED' } });
      return { ok: true, status: 200, blob: async () => file };
    }
    if (url.endsWith('/auth/refresh')) return json(200, { user, refreshToken: 'refresh-2', accessToken: 'token-2' });
    const weekly = url.endsWith('/reports?period=weekly');
    return json(200, {
      areas: [{ id: areaId, name: 'Village North', districtName: 'Synthetic District' }],
      reports: weekly ? [report] : [], nextBefore: null,
    });
  });

  try {
    renderApp('/reports', { session });
    expect(await screen.findByRole('heading', { name: 'Reports' })).toBeInTheDocument();
    expect(await screen.findByText('Village North', { selector: 'strong' })).toBeInTheDocument();
    expect(screen.getByText('Preparing Excel')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /Download PDF for Village North/ }));
    await screen.findByText('Download started.');
    expect(create).toHaveBeenCalledWith(file);
    expect(download.mock.contexts[0].download).toBe(`mediqore-weekly-2026-05-25-${areaId}.pdf`);
    expect(fetch.mock.calls.filter(([url]) => url.endsWith('/download')).map(([, value]) => value.headers.Authorization))
      .toEqual(['Bearer token-1', 'Bearer token-2']);

    fireEvent.change(screen.getByLabelText('Report period'), { target: { value: 'monthly' } });
    expect(await screen.findByText('No completed monthly periods have been scheduled for these areas.')).toBeInTheDocument();
  } finally {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
    [URL.createObjectURL, URL.revokeObjectURL] = originals;
    download.mockRestore();
  }
});
