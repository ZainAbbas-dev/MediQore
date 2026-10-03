import '@testing-library/jest-dom';
import { TextDecoder, TextEncoder } from 'node:util';

// React Router needs these; jsdom does not provide them.
Object.assign(globalThis, { TextEncoder, TextDecoder });

afterEach(() => {
  sessionStorage.clear();
  jest.restoreAllMocks();
});
