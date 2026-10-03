import { useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/context';

const MESSAGES = {
  INVALID_CREDENTIALS: 'Username or password is incorrect.',
  PORTAL_ROLE: 'This portal is for supervisors and admins. LHWs use the mobile app.',
  NETWORK_ERROR: 'Cannot reach the server. Check that the API is running.',
};

export default function LoginPage() {
  const { token, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const target = location.state?.from || '/';
  if (token) return <Navigate to={target} replace />;

  async function handleSubmit(event) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(username.trim(), password);
      navigate(target, { replace: true });
    } catch (err) {
      setError(MESSAGES[err.code] || `Sign-in failed (${err.code || 'error'}).`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={handleSubmit}>
        <h1>MediQore</h1>
        <p className="muted">Supervisor and admin portal</p>
        <label htmlFor="username">Username</label>
        <input id="username" autoComplete="username" value={username} onChange={(e) => setUsername(e.target.value)} required />
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        {error && (
          <p className="error" role="alert">
            {error}
          </p>
        )}
        <button type="submit" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
