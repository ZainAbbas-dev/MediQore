import { useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

export function childAnalyticsQuery(values) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `?${query}` : '';
}

export function useChildAnalytics(endpoint, selection = {}) {
  const { request } = useAuth();
  const [result, setResult] = useState(null);
  const url = `/child-analytics/${endpoint}${childAnalyticsQuery(selection)}`;

  useEffect(() => {
    let cancelled = false;
    request(url).then(
      (data) => { if (!cancelled) setResult({ url, data }); },
      (error) => { if (!cancelled) setResult({ url, error: error.message }); },
    );
    return () => { cancelled = true; };
  }, [request, url]);

  return result?.url === url ? result : {};
}
