const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, insertActivatedDevice, tokenFor, closePool, query } = require('./db');

const app = createApp();

function household(overrides = {}) {
  return {
    table: 'households',
    id: randomUUID(),
    createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { householdNumber: 'H-1', address: 'Street 1', village: 'Test Village', latitude: 33.6844, longitude: 73.0479 },
    ...overrides,
  };
}

describeDb('sync', () => {
  let ids;
  let lhwA;
  let lhwB;
  let deviceA;
  let deviceB;

  const push = (token, deviceId, records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${token}`).send({ deviceId, records });
  const pull = (token, query = '') =>
    request(app).get(`/api/v1/sync/pull${query}`).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    ({ deviceA, deviceB } = ids);
    lhwA = tokenFor(ids.lhwA, 'lhw', deviceA);
    lhwB = tokenFor(ids.lhwB, 'lhw', deviceB);
  });

  afterAll(closePool);

  describe('POST /api/v1/sync/push', () => {
    it('stores a new record in the LHW area with a server sequence number and an audit row', async () => {
      const record = household();

      const res = await push(lhwA, deviceA, [record]);

      expect(res.status).toBe(200);
      const [result] = res.body.results;
      expect(result).toMatchObject({ table: 'households', id: record.id, status: 'created' });
      expect(result.serverSeq).toBeGreaterThan(0);

      const { rows: [row] } = await query('SELECT * FROM households WHERE id = $1', [record.id]);
      expect(row).toMatchObject({ area_id: ids.areaA, created_by: ids.lhwA, village: 'Test Village' });
      expect(Number(row.server_seq)).toBe(result.serverSeq);

      const { rows: audit } = await query(
        `SELECT user_id, device_id FROM audit_log WHERE action = 'create' AND entity_id = $1`, [record.id]);
      expect(audit).toEqual([{ user_id: ids.lhwA, device_id: deviceA }]);
    });

    it('treats a resend of the same record as harmless', async () => {
      const record = household();
      const first = await push(lhwA, deviceA, [record]);

      const again = await push(lhwA, deviceA, [record]);

      expect(again.body.results[0]).toEqual({ ...first.body.results[0], status: 'unchanged' });
      const { rows } = await query('SELECT count(*)::int AS n FROM audit_log WHERE entity_id = $1', [record.id]);
      expect(rows[0].n).toBe(1);
    });

    it('replays the committed operation after another phone edits the record, without another write', async () => {
      const original = household({ operationId: randomUUID() });
      const created = await push(lhwA, deviceA, [original]);
      expect(created.status).toBe(200);
      const otherPhone = await insertActivatedDevice(ids.lhwA);
      const otherToken = tokenFor(ids.lhwA, 'lhw', otherPhone);
      const edit = { ...original, operationId: randomUUID(), baseVersion: 1, data: { ...original.data, village: 'New village' } };
      expect((await push(otherToken, otherPhone, [edit])).body.results[0]).toMatchObject({ status: 'updated', version: 2 });

      const retry = await push(lhwA, deviceA, [original]);
      expect(retry.body.results).toEqual(created.body.results);
      const { rows: [row] } = await query('SELECT village, version FROM households WHERE id = $1', [original.id]);
      expect(row).toEqual({ village: 'New village', version: 2 });
      const { rows: [audit] } = await query('SELECT count(*)::int AS total FROM audit_log WHERE entity_id = $1', [original.id]);
      expect(audit.total).toBe(2);
    });

    it('rejects operation ID reuse with a different mutation and waits for an out-of-order base version', async () => {
      const record = household({ operationId: randomUUID() });
      expect((await push(lhwA, deviceA, [record])).status).toBe(200);
      const changed = { ...record, data: { ...record.data, village: 'New village' } };
      expect((await push(lhwA, deviceA, [changed])).body.results[0]).toMatchObject({
        status: 'rejected', reason: 'OPERATION_ID_REUSED',
      });

      const future = { ...changed, operationId: randomUUID(), baseVersion: 2 };
      expect((await push(lhwA, deviceA, [future])).body.results[0]).toMatchObject({
        status: 'rejected', reason: 'VERSION_AHEAD',
      });
      const previous = { ...record, operationId: randomUUID(), baseVersion: 1, data: { ...record.data, village: 'First edit' } };
      expect((await push(lhwA, deviceA, [previous])).body.results[0]).toMatchObject({ status: 'updated', version: 2 });
      expect((await push(lhwA, deviceA, [future])).body.results[0]).toMatchObject({ status: 'updated', version: 3 });
      const { rows: [row] } = await query('SELECT village, version FROM households WHERE id = $1', [record.id]);
      expect(row).toEqual({ village: 'New village', version: 3 });
    });

    it('preserves distinct legacy edits when their original base is unavailable', async () => {
      const record = household();
      await push(lhwA, deviceA, [record]);
      const edits = ['Offline edit one', 'Offline edit two'].map((village) => ({ ...record, data: { ...record.data, village } }));
      const first = (await push(lhwA, deviceA, [edits[0]])).body.results[0];
      const next = (await push(lhwA, deviceA, [edits[1]])).body.results[0];
      expect(first.status).toBe('conflict');
      expect(next.status).toBe('conflict');
      expect(next.conflictId).not.toBe(first.conflictId);
      expect((await push(lhwA, deviceA, [edits[0]])).body.results[0]).toEqual(first);
      const { rows: [stored] } = await query('SELECT village, version FROM households WHERE id = $1', [record.id]);
      expect(stored).toEqual({ village: record.data.village, version: 1 });
    });

    it('retains separate stale candidates for one record and identifies held edits on the submitting phone', async () => {
      const record = household({ operationId: randomUUID() });
      await push(lhwA, deviceA, [record]);
      const otherPhone = await insertActivatedDevice(ids.lhwA);
      const otherToken = tokenFor(ids.lhwA, 'lhw', otherPhone);
      const changed = (village) => ({ ...record, operationId: randomUUID(), baseVersion: 1, data: { ...record.data, village } });
      expect((await push(lhwA, deviceA, [changed('Server edit')])).body.results[0].status).toBe('updated');
      const first = changed('Offline edit one');
      const second = changed('Offline edit two');
      const [a] = (await push(lhwA, deviceA, [first])).body.results;
      const [b] = (await push(otherToken, otherPhone, [second])).body.results;
      expect(a.status).toBe('conflict');
      expect(b.status).toBe('conflict');
      expect(a.conflictId).not.toBe(b.conflictId);
      expect((await push(lhwA, deviceA, [first])).body.results).toEqual([a]);

      const pulled = (await pull(lhwA)).body.records.find(({ id }) => id === record.id);
      expect(pulled).toMatchObject({ pendingConflictIds: [a.conflictId], data: { village: 'Server edit' } });
      const { rows } = await query(
        'SELECT incoming_payload FROM sync_conflicts WHERE incoming_record_id = $1 AND status = $2', [record.id, 'pending']);
      expect(rows.map(({ incoming_payload }) => incoming_payload.data.village).sort()).toEqual(['Offline edit one', 'Offline edit two']);
    });

    it('applies an edit with a new, higher sequence number', async () => {
      const record = household();
      const first = await push(lhwA, deviceA, [record]);

      const edited = { ...record, baseVersion: 1, data: { ...record.data, village: 'Moved Village' } };
      const res = await push(lhwA, deviceA, [edited]);

      const [result] = res.body.results;
      expect(result.status).toBe('updated');
      expect(result.serverSeq).toBeGreaterThan(first.body.results[0].serverSeq);
      const { rows: [audit] } = await query(
        `SELECT action FROM audit_log WHERE entity_id = $1 ORDER BY id DESC LIMIT 1`, [record.id]);
      expect(audit.action).toBe('edit');
    });

    it('soft-deletes a record marked deleted', async () => {
      const record = household();
      await push(lhwA, deviceA, [record]);

      const res = await push(lhwA, deviceA, [{ ...record, baseVersion: 1, deleted: true }]);

      expect(res.body.results[0].status).toBe('updated');
      const { rows: [row] } = await query('SELECT deleted_at FROM households WHERE id = $1', [record.id]);
      expect(row.deleted_at).not.toBeNull();
      const { rows: [audit] } = await query(
        `SELECT action FROM audit_log WHERE entity_id = $1 ORDER BY id DESC LIMIT 1`, [record.id]);
      expect(audit.action).toBe('delete');
    });

    it('rejects a change to a record from another area', async () => {
      const record = household();
      await push(lhwA, deviceA, [record]);

      const res = await push(lhwB, deviceB, [{ ...record, data: { ...record.data, village: 'Hijack' } }]);

      expect(res.body.results[0]).toMatchObject({ status: 'rejected', reason: 'OUT_OF_AREA' });
      const { rows: [row] } = await query('SELECT village FROM households WHERE id = $1', [record.id]);
      expect(row.village).toBe('Test Village');
    });

    it('refuses a device registered to another user', async () => {
      const res = await push(lhwB, deviceA, [household()]);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('DEVICE_NOT_ALLOWED');
    });

    it('refuses a phone that has not been activated with an activation code (M1 FE-2)', async () => {
      const pending = randomUUID();
      await query('INSERT INTO devices (id, user_id) VALUES ($1, $2)', [pending, ids.lhwA]);

      const res = await push(tokenFor(ids.lhwA, 'lhw', pending), pending, [household()]);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('DEVICE_NOT_ALLOWED');
    });

    it('rounds coordinates to the stored precision so a resend stays unchanged', async () => {
      const record = household({ data: { village: 'GPS', latitude: 33.123456789, longitude: 73.987654321 } });
      await push(lhwA, deviceA, [record]);

      const again = await push(lhwA, deviceA, [record]);

      expect(again.body.results[0].status).toBe('unchanged');
    });

    it.each([
      ['an unknown table', { table: 'users' }],
      ['an id that is not a UUID v4', { id: '123' }],
      ['latitude without longitude', { data: { village: 'X', latitude: 33.6 } }],
      ['a missing createdOnDevice', { createdOnDevice: undefined }],
    ])('rejects %s with 400', async (_, overrides) => {
      const res = await push(lhwA, deviceA, [household(overrides)]);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('limits a batch to 100 records', async () => {
      const records = Array.from({ length: 101 }, () => household());

      const res = await push(lhwA, deviceA, records);

      expect(res.status).toBe(400);
    });

    it('is only for LHWs', async () => {
      const res = await push(tokenFor(ids.supervisorA, 'supervisor'), randomUUID(), [household()]);

      expect(res.status).toBe(403);
    });
  });

  describe('GET /api/v1/sync/pull', () => {
    it('returns only the LHW area, oldest first, with a cursor for the next pull', async () => {
      await push(lhwB, deviceB, [household({ data: { village: 'B village' } })]);

      const res = await pull(lhwA);

      expect(res.status).toBe(200);
      const seqs = res.body.records.map((r) => r.serverSeq);
      expect(seqs).toEqual([...seqs].sort((a, b) => a - b));
      expect(res.body.records.map((r) => r.data.village)).not.toContain('B village');
      expect(res.body.nextSince).toBe(seqs[seqs.length - 1]);
      expect(res.body.hasMore).toBe(false);

      const next = await pull(lhwA, `?since=${res.body.nextSince}`);
      expect(next.body).toEqual({ records: [], nextSince: res.body.nextSince, hasMore: false });
    });

    it('returns changes made after the cursor, including soft deletes', async () => {
      const { body: before } = await pull(lhwA);
      const record = household();
      await push(lhwA, deviceA, [record]);
      await push(lhwA, deviceA, [{ ...record, baseVersion: 1, deleted: true }]);

      const res = await pull(lhwA, `?since=${before.nextSince}`);

      expect(res.body.records).toHaveLength(1);
      expect(res.body.records[0]).toMatchObject({ id: record.id, deleted: true, table: 'households' });
    });

    it('pages with limit and hasMore', async () => {
      const res = await pull(lhwA, '?limit=2');

      expect(res.body.records).toHaveLength(2);
      expect(res.body.hasMore).toBe(true);
    });

    it('validates the query', async () => {
      const res = await pull(lhwA, '?since=-1');

      expect(res.status).toBe(400);
    });
  });

  it('reconciles 1,000 operations across three phones with exact cursor coverage and no extra writes', async () => {
    const cursor = (await pull(lhwA, '?limit=500')).body.nextSince;
    const devices = [deviceA, await insertActivatedDevice(ids.lhwA), await insertActivatedDevice(ids.lhwA)];
    const tokens = devices.map((id) => tokenFor(ids.lhwA, 'lhw', id));
    const records = Array.from({ length: 1000 }, () => household({ operationId: randomUUID() }));
    const batches = Array.from({ length: 10 }, (_, i) => records.slice(i * 100, (i + 1) * 100));
    await Promise.all(devices.map(async (device, index) => {
      for (const [i, batch] of batches.entries()) {
        if (i % devices.length !== index) continue;
        const sent = await push(tokens[index], device, batch);
        expect(sent.status).toBe(200);
        expect(sent.body.results.map(({ status }) => status)).toEqual(batch.map(() => 'created'));
        expect((await push(tokens[index], device, batch)).body.results).toEqual(sent.body.results);
      }
    }));

    const expected = records.map(({ id }) => id).sort();
    await Promise.all(tokens.map(async (token) => {
      let since = cursor;
      const seen = [];
      const order = [];
      while (true) {
        const page = await pull(token, `?since=${since}&limit=137`);
        expect(page.status).toBe(200);
        const pulled = page.body.records;
        seen.push(...pulled.map(({ id }) => id));
        order.push(...pulled.map(({ serverSeq }) => serverSeq));
        if (!page.body.hasMore) break;
        expect(page.body.nextSince).toBeGreaterThan(since);
        since = page.body.nextSince;
      }
      expect(seen.sort()).toEqual(expected);
      expect(order.every((seq, i) => i === 0 || seq > order[i - 1])).toBe(true);
    }));
    const { rows: [audit] } = await query(
      'SELECT count(*)::int AS total FROM audit_log WHERE entity_id = ANY($1::uuid[])', [expected]);
    expect(audit.total).toBe(1000);
  }, 30_000);

});
