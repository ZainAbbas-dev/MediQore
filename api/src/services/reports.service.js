const { createHash } = require('node:crypto');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const logger = require('../utils/logger');
const { managedAreaIds } = require('./scope.service');
const { writeAudit } = require('./audit.service');
const { collectReport } = require('./reports-data.service');
const { renderReport } = require('./reports-render.service');

const TYPE = 'health_summary';
const POLL_INTERVAL_MS = 60_000;
const CYCLE_LIMIT = 40;
const FORMATS = {
  pdf: 'application/pdf',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};
const AREA_JOINS = `JOIN union_councils uc ON uc.id = a.union_council_id
  JOIN tehsils t ON t.id = uc.tehsil_id JOIN districts d ON d.id = t.district_id`;
const SCOPE_SNAPSHOT = 'jsonb_build_array(a.name, uc.name, t.name, d.name)';
const JOB_CHANGED = `j.source_revision IS DISTINCT FROM coalesce(r.revision, 0)
  OR j.scope_snapshot IS DISTINCT FROM ${SCOPE_SNAPSHOT}`;

// On first run, generate the most recently completed period of each type. On
// restart, also catch up every interval the scheduler missed while offline.
async function enqueue(now) {
  await db.query(
    `WITH period_types (period, trunc_unit, duration) AS (
       VALUES ('weekly', 'week', interval '1 week'), ('monthly', 'month', interval '1 month')
     ), ends AS (
       SELECT p.*, date_trunc(p.trunc_unit, $1::timestamptz AT TIME ZONE 'Asia/Karachi') AS current_start
       FROM period_types p
     )
     INSERT INTO report_jobs (report_type, period, format, area_id, period_start, period_end)
     SELECT $2, e.period, f.format, a.id, s.begins::date, (s.begins + e.duration)::date - 1
     FROM areas a CROSS JOIN ends e CROSS JOIN (VALUES ('pdf'), ('xlsx')) f(format)
     LEFT JOIN LATERAL (
       SELECT max(j.period_start) AS latest
       FROM report_jobs j WHERE j.report_type = $2 AND j.area_id = a.id AND j.period = e.period
     ) previous ON true
     CROSS JOIN LATERAL generate_series(
       coalesce(previous.latest + e.duration, e.current_start - e.duration),
       e.current_start - e.duration, e.duration
     ) s(begins)
     WHERE a.deleted_at IS NULL
     ON CONFLICT (report_type, period, area_id, period_start, format) DO NOTHING`,
    [now, TYPE],
  );
}

async function changedPeriods(limit) {
  const { rows } = await db.query(
    `SELECT j.area_id AS "areaId", j.period, j.period_start AS "periodStart"
     FROM report_jobs j JOIN areas a ON a.id = j.area_id ${AREA_JOINS}
     LEFT JOIN report_source_revisions r ON r.area_id = a.id
     WHERE j.report_type = $1 AND a.deleted_at IS NULL
       AND (j.status <> 'done' OR ${JOB_CHANGED})
     GROUP BY j.area_id, j.period, j.period_start
     ORDER BY bool_or(j.status = 'queued') DESC, min(j.finished_at) NULLS FIRST,
              j.period_start DESC, j.area_id, j.period LIMIT $2`,
    [TYPE, limit],
  );
  return rows;
}

async function processPeriod({ areaId, period, periodStart }, render) {
  return db.withTransaction(async (client) => {
    await client.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
    // Keep only one renderer active across API instances. The transaction and
    // its lock roll back if a process exits during rendering.
    const { rows: [{ locked }] } = await client.query('SELECT pg_try_advisory_xact_lock(174318, 10) AS locked');
    if (!locked) return false;
    const { rows: jobs } = await client.query(
      `SELECT j.id, j.format, j.period_end, j.status, j.content_hash, j.output_bytes IS NOT NULL AS has_file,
              coalesce(r.revision, 0) AS revision, (${JOB_CHANGED}) AS changed,
              ${SCOPE_SNAPSHOT} AS scope,
              a.name AS "areaName", uc.name AS "unionCouncilName", t.name AS "tehsilName", d.name AS "districtName"
       FROM report_jobs j JOIN areas a ON a.id = j.area_id ${AREA_JOINS}
       LEFT JOIN report_source_revisions r ON r.area_id = a.id
       WHERE j.report_type = $1 AND j.area_id = $2 AND j.period = $3 AND j.period_start = $4
         AND a.deleted_at IS NULL
       ORDER BY j.format DESC FOR UPDATE OF j`,
      [TYPE, areaId, period, periodStart],
    );
    const pending = jobs.filter((job) => job.status !== 'done' || job.changed);
    if (!pending.length) return true;
    const [{ period_end: periodEnd, areaName, unionCouncilName, tehsilName, districtName, revision, scope }] = pending;
    const area = { id: areaId, areaName, unionCouncilName, tehsilName, districtName };
    const report = await collectReport(client, { area, period, periodStart, periodEnd });
    const hash = createHash('sha256').update(JSON.stringify(report)).digest('hex');
    for (const job of pending) {
      if (job.has_file && job.content_hash === hash) {
        await client.query(
          `UPDATE report_jobs SET source_revision = $2, scope_snapshot = $3, status = 'done', error = NULL WHERE id = $1`,
          [job.id, revision, JSON.stringify(scope)],
        );
        continue;
      }
      await client.query("UPDATE report_jobs SET status = 'running', started_at = clock_timestamp() WHERE id = $1", [job.id]);
      let output;
      try {
        output = await render(job.format, report);
      } catch (error) {
        logger.warn('Report rendering failed', { jobId: job.id, format: job.format, message: error.message });
        await client.query(
          `UPDATE report_jobs SET status = 'failed', error = 'Rendering failed',
           finished_at = CASE WHEN output_bytes IS NULL THEN clock_timestamp() ELSE finished_at END WHERE id = $1`,
          [job.id],
        );
        continue;
      }
      await client.query(
        `UPDATE report_jobs SET status = 'done', output_bytes = $2, source_revision = $3, scope_snapshot = $4,
          content_hash = $5, error = NULL, finished_at = clock_timestamp() WHERE id = $1`,
        [job.id, output, revision, JSON.stringify(scope), hash],
      );
    }
    return true;
  });
}

async function runReportCycle({ now = new Date(), render = renderReport, limit = CYCLE_LIMIT, signal } = {}) {
  await enqueue(now);
  for (const period of await changedPeriods(limit)) {
    if (signal?.aborted || !(await processPeriod(period, render))) break;
  }
}

function startReportScheduler() {
  if (process.env.REPORTS_ENABLED === 'false') return async () => {};
  if (!process.env.CHROME_PATH) logger.warn('Set CHROME_PATH to enable scheduled PDF rendering');
  const controller = new AbortController();
  let running;
  function tick() {
    if (running) return;
    running = runReportCycle({ signal: controller.signal }).catch((error) => {
      logger.error('Report scheduler failed', { message: error.message });
    }).finally(() => { running = null; });
  }
  const timer = setInterval(tick, POLL_INTERVAL_MS);
  timer.unref();
  tick();
  return async () => {
    clearInterval(timer);
    controller.abort();
    await running;
  };
}

function decodeBefore(before) {
  if (!before) return [null, null];
  const cursor = Buffer.from(before, 'base64url').toString();
  const match = /^(\d{4}-\d{2}-\d{2})\|([\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12})$/i.exec(cursor);
  if (match) {
    const [, day, areaId] = match;
    const epoch = Date.parse(day);
    if (day.slice(0, 4) !== '0000' && Number.isFinite(epoch) && new Date(epoch).toISOString().slice(0, 10) === day) {
      return [day, areaId];
    }
  }
  throw new AppError(400, 'VALIDATION_ERROR', 'Invalid report page cursor');
}

async function list(viewer, { period, areaId, before, limit }) {
  const [beforeDate, beforeArea] = decodeBefore(before);
  return db.withTransaction(async (client) => {
    const scoped = await managedAreaIds(client, viewer);
    const { rows: areas } = await client.query(
      `SELECT a.id, a.name, d.name AS "districtName" FROM areas a ${AREA_JOINS}
       WHERE a.deleted_at IS NULL AND ($1::uuid[] IS NULL OR a.id = ANY($1))
       ORDER BY d.name, a.name, a.id`,
      [scoped],
    );
    if (areaId && !areas.some((area) => area.id === areaId)) {
      throw new AppError(404, 'AREA_NOT_FOUND', 'Area not found');
    }
    const { rows } = await client.query(
      `SELECT j.area_id AS "areaId", a.name AS "areaName", d.name AS "districtName", j.period,
              j.period_start AS "periodStart", j.period_end AS "periodEnd",
              jsonb_object_agg(j.format, jsonb_build_object('id', j.id, 'status', j.status,
                'generatedAt', CASE WHEN j.output_bytes IS NOT NULL THEN j.finished_at END,
                'available', j.output_bytes IS NOT NULL)) AS files
       FROM report_jobs j JOIN areas a ON a.id = j.area_id ${AREA_JOINS}
       WHERE j.report_type = $1 AND j.period = $2 AND j.area_id = ANY($3::uuid[])
         AND ($4::date IS NULL OR (j.period_start, j.area_id) < ($4, $5::uuid))
       GROUP BY j.area_id, a.name, d.name, j.period, j.period_start, j.period_end
       ORDER BY j.period_start DESC, j.area_id DESC LIMIT $6`,
      [TYPE, period, areaId ? [areaId] : areas.map((area) => area.id), beforeDate, beforeArea, limit + 1],
    );
    const reports = rows.slice(0, limit);
    const last = reports.at(-1);
    const nextBefore = rows.length > limit ? Buffer.from(`${last.periodStart}|${last.areaId}`).toString('base64url') : null;
    return { reports, areas, nextBefore };
  }, { readOnly: true });
}

async function download(viewer, id) {
  return db.withTransaction(async (client) => {
    const areaIds = await managedAreaIds(client, viewer);
    const { rows: [job] } = await client.query(
      `SELECT j.area_id, j.period, j.period_start, j.format, j.output_bytes
       FROM report_jobs j JOIN areas a ON a.id = j.area_id
       WHERE j.id = $1 AND j.report_type = $2 AND a.deleted_at IS NULL AND j.output_bytes IS NOT NULL
         AND ($3::uuid[] IS NULL OR j.area_id = ANY($3))`,
      [id, TYPE, areaIds],
    );
    if (!job) throw new AppError(404, 'REPORT_NOT_FOUND', 'Report file not found');
    await writeAudit(client, {
      userId: viewer.id, action: 'report_download', entityType: 'report_jobs', entityId: id,
      details: { areaId: job.area_id, period: job.period, periodStart: job.period_start, format: job.format },
    });
    return {
      contentType: FORMATS[job.format],
      filename: `mediqore-${job.period}-${job.period_start}-${job.area_id}.${job.format}`,
      bytes: job.output_bytes,
    };
  });
}

module.exports = { list, download, runReportCycle, startReportScheduler };
