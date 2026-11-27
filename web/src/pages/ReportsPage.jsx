import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const formats = { pdf: 'PDF', xlsx: 'Excel' };
const date = new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium', timeZone: 'Asia/Karachi' });
const timestamp = new Intl.DateTimeFormat('en-GB', {
  dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Karachi',
});

function fileStatus(file, label) {
  if (file?.status === 'failed') return file.available ? `Updating ${label} will retry` : `${label} generation will retry`;
  return `Preparing ${label}`;
}

function saveFile(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export default function ReportsPage() {
  const { request } = useAuth();
  const [period, setPeriod] = useState('weekly');
  const [areaId, setAreaId] = useState('');
  const [version, setVersion] = useState(0);
  const [listing, setListing] = useState(null);
  const [areas, setAreas] = useState([]);
  const [listingError, setListingError] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [downloading, setDownloading] = useState(null);
  const [downloadMessage, setDownloadMessage] = useState(null);

  const fetchReports = useCallback((before) => {
    const params = new URLSearchParams({ period });
    if (areaId) params.set('areaId', areaId);
    if (before) params.set('before', before);
    return request(`/reports?${params}`);
  }, [period, areaId, request]);

  useEffect(() => {
    let disposed = false;
    fetchReports().then((data) => {
      if (disposed) return;
      setListing(data);
      setAreas(data.areas);
    }).catch((error) => {
      if (!disposed) setListingError(error.message);
    });
    return () => { disposed = true; };
  }, [fetchReports, version]);

  function changeListing(update) {
    setListing(null);
    setListingError(null);
    update();
  }

  async function loadMore() {
    setLoadingMore(true);
    setListingError(null);
    try {
      const page = await fetchReports(listing.nextBefore);
      setListing({ ...page, reports: [...listing.reports, ...page.reports] });
    } catch (error) {
      setListingError(error.message);
    } finally {
      setLoadingMore(false);
    }
  }

  async function download(report, format, id) {
    setDownloading(id);
    setDownloadMessage(null);
    try {
      const blob = await request(`/reports/${id}/download`, { responseType: 'blob' });
      saveFile(blob, `mediqore-${report.period}-${report.periodStart}-${report.areaId}.${format}`);
      setDownloadMessage({ text: 'Download started.' });
    } catch (error) {
      setDownloadMessage({ text: error.message, failed: true });
    } finally {
      setDownloading(null);
    }
  }

  const reports = listing?.reports;
  return (
    <>
      <h1>Reports</h1>
      <div className="toolbar wrap">
        <label htmlFor="report-period">Report period</label>
        <select id="report-period" value={period} disabled={loadingMore} onChange={(event) => changeListing(() => setPeriod(event.target.value))}>
          <option value="weekly">Weekly</option>
          <option value="monthly">Monthly</option>
        </select>
        <label htmlFor="report-area">Area</label>
        <select id="report-area" value={areaId} disabled={loadingMore} onChange={(event) => changeListing(() => setAreaId(event.target.value))}>
          <option value="">All assigned areas</option>
          {areas.map((area) => <option key={area.id} value={area.id}>{area.name} · {area.districtName}</option>)}
        </select>
        <button type="button" className="secondary" disabled={loadingMore} onClick={() => changeListing(() => setVersion((value) => value + 1))}>
          Refresh
        </button>
      </div>
      {listingError && <p className="error" role="alert">{listingError}</p>}
      {!listing && !listingError && <p className="muted" role="status">Loading reports…</p>}
      {reports?.length === 0 && <p className="muted">No completed {period} periods have been scheduled for these areas.</p>}
      {downloadMessage && (
        <p className={downloadMessage.failed ? 'error' : 'muted'} role={downloadMessage.failed ? 'alert' : 'status'}>
          {downloadMessage.text}
        </p>
      )}
      {reports?.length > 0 && (
        <div className="table-scroll" tabIndex={0} aria-label="Report downloads">
          <table>
            <thead><tr><th scope="col">Period (Pakistan time)</th><th scope="col">Area</th><th scope="col">PDF</th><th scope="col">Excel</th></tr></thead>
            <tbody>
              {reports.map((report) => {
                const from = date.format(new Date(`${report.periodStart}T00:00:00Z`));
                const to = date.format(new Date(`${report.periodEnd}T00:00:00Z`));
                return (
                  <tr key={`${report.periodStart}-${report.areaId}`}>
                    <td>{from} – {to}</td>
                    <td><strong>{report.areaName}</strong><div className="muted">{report.districtName}</div></td>
                    {Object.entries(formats).map(([format, label]) => {
                      const file = report.files[format];
                      return (
                        <td key={format}>
                          {file?.available && (
                            <>
                              <button type="button" className="secondary" disabled={Boolean(downloading)}
                                aria-label={`Download ${label} for ${report.areaName}, ${from} to ${to}`}
                                onClick={() => download(report, format, file.id)}>
                                {downloading === file.id ? 'Downloading…' : `Download ${label}`}
                              </button>
                              <div className="muted">{timestamp.format(new Date(file.generatedAt))}</div>
                            </>
                          )}
                          {file?.status !== 'done' && <div className="muted">{fileStatus(file, label)}</div>}
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {listing?.nextBefore && (
        <button type="button" className="secondary" disabled={loadingMore} onClick={loadMore}>
          {loadingMore ? 'Loading…' : 'Show older reports'}
        </button>
      )}
    </>
  );
}
