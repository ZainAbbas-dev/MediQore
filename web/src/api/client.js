import { API_BASE_URL } from '../runtime-config';

// An error answer from the API, in its standard { error: { code, message } } shape.
export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

// Calls the REST API (docs/openapi.yaml) and returns parsed JSON or a requested file.
export async function apiRequest(path, { method = 'GET', body, token, responseType } = {}) {
  const headers = { Accept: responseType === 'blob' ? '*/*' : 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'NETWORK_ERROR', 'Cannot reach the server');
  }

  if (response.ok && responseType === 'blob') return response.blob();
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    // A body that is not JSON (for example a proxy error page) still has an HTTP status.
  }
  if (!response.ok) {
    const error = data.error || {};
    throw new ApiError(response.status, error.code || `HTTP_${response.status}`, error.message || response.statusText);
  }
  return data;
}
