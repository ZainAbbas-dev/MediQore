// M1 FE-2: PIN reset reply codes. An LHW who forgot her PIN reads the 6-digit
// code on her phone to her supervisor, who picks her here, types the code and
// reads back the 8-digit reply. The phone checks the reply offline and keeps
// its data. Supervisors see the LHWs in their areas; admins see every LHW.
import { useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const formatTime = (value) => (value ? new Date(value).toLocaleString() : '–');

export default function PinResetPage() {
  const { request } = useAuth();
  const [lhws, setLhws] = useState(null);
  const [lhwId, setLhwId] = useState('');
  const [challenge, setChallenge] = useState('');
  const [reply, setReply] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    request('/dashboard/filters')
      .then((data) => setLhws(data.lhws))
      .catch((err) => setError(err.message));
  }, [request]);

  async function handleSubmit(event) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    setReply(null);
    try {
      setReply(await request('/pin-reset/reply-code', { method: 'POST', body: { lhwId, challenge: challenge.replace(/\s/g, '') } }));
      setChallenge('');
    } catch (err) {
      setError(
        err.code === 'NO_ACTIVATED_PHONE'
          ? 'This LHW has no activated phone. She needs a new activation code from an admin.'
          : err.code === 'VALIDATION_ERROR'
            ? 'Type the 6 digits shown on her phone.'
            : err.message,
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h1>PIN reset codes</h1>
      <p className="muted">
        When an LHW forgets her PIN, her phone shows a 6-digit code. Ask her for it on a call, choose her name, type the
        code and read the reply code back to her. She types it on her phone and sets a new PIN. No internet is needed on
        her phone, and her records stay on it.
      </p>
      <form onSubmit={handleSubmit} className="stack narrow">
        <label htmlFor="reset-lhw">LHW</label>
        <select id="reset-lhw" value={lhwId} onChange={(e) => setLhwId(e.target.value)} required>
          <option value="">Choose an LHW</option>
          {(lhws ?? []).map((lhw) => (
            <option key={lhw.id} value={lhw.id}>
              {lhw.lhwCode} · {lhw.fullName}
            </option>
          ))}
        </select>
        <label htmlFor="reset-challenge">Code on her phone</label>
        <input
          id="reset-challenge"
          className="mono"
          inputMode="numeric"
          autoComplete="off"
          placeholder="6 digits"
          value={challenge}
          onChange={(e) => setChallenge(e.target.value)}
          pattern="\s*(\d\s*){6}"
          required
        />
        {error && (
          <p className="error" role="alert">
            {error}
          </p>
        )}
        <div className="actions">
          <button type="submit" disabled={busy}>
            Get reply code
          </button>
        </div>
      </form>
      {reply && (
        <section className="notice" aria-label="Reply code">
          <p>
            Reply code for <strong>{reply.lhw.fullName}</strong> ({reply.lhw.lhwCode}):
          </p>
          <p className="code">{reply.replyCode}</p>
          <p className="muted">
            It works only for the code you typed, on her phone activated on {formatTime(reply.device.activatedAt)}
            {reply.device.model ? ` (${reply.device.model})` : ''}. It is not shown again; this request is in the audit log.
          </p>
          <button type="button" className="secondary" onClick={() => setReply(null)}>
            Done
          </button>
        </section>
      )}
    </>
  );
}
