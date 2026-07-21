// tests/k6/during-deploy.js
// ─────────────────────────────────────────────────────────────────────────────
// Continuous 10-minute load test designed to run DURING a progressive delivery.
//
// What it measures:
//   • http_req_failed  — must be 0.00% throughout the deploy
//   • http_req_duration p(95) — must stay below 200ms
//   • http_req_duration p(99) — tracked as secondary indicator
//
// Thresholds are HARD-FAIL: if either is breached, k6 exits with code 1 and
//   verify-zero-downtime.sh will report FAIL.
//
// Usage:
//   k6 run --env BASE_URL=http://localhost:8080 tests/k6/during-deploy.js
//   make load-during   (sets BASE_URL from Makefile env)
// ─────────────────────────────────────────────────────────────────────────────

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// ── Custom metrics ────────────────────────────────────────────────────────────
const v1Requests  = new Counter('v1_requests_total');
const v2Requests  = new Counter('v2_requests_total');
const versionSeen = new Rate('v2_traffic_seen');   // tracks canary promotion

// ── Test configuration ────────────────────────────────────────────────────────
export const options = {
  // Ramp up to 50 VUs over 1 minute, hold for 8 minutes, ramp down 1 minute.
  // Total: 10 minutes — covers the entire canary deploy window.
  stages: [
    { duration: '1m',  target: 50  },  // ramp-up
    { duration: '8m',  target: 50  },  // steady load during deploy
    { duration: '1m',  target: 0   },  // ramp-down
  ],

  // ── Zero-downtime SLOs ─────────────────────────────────────────────────────
  thresholds: {
    // Zero errors — this is the PRIMARY zero-downtime gate.
    'http_req_failed':                ['rate==0'],

    // p95 must stay under 200ms at all times.
    'http_req_duration{path:/api}':   ['p(95)<200'],

    // p99 is a warning indicator (soft threshold — does not fail the test).
    // Uncomment the line below to make it hard:
    // 'http_req_duration{path:/api}': ['p(99)<500'],
  },

  // Output summary as JSON for verify-zero-downtime.sh to parse.
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

// ── Setup: confirm service is reachable before the test begins ────────────────
export function setup() {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  const health  = http.get(`${baseUrl}/healthz`);
  if (health.status !== 200) {
    throw new Error(`Healthcheck failed: ${health.status} ${health.body}`);
  }
  console.log(`[setup] Service healthy at ${baseUrl}`);
  return { baseUrl };
}

// ── Main VU loop ──────────────────────────────────────────────────────────────
export default function (data) {
  const { baseUrl } = data;

  // ── /api request ──────────────────────────────────────────────────────────
  const res = http.get(`${baseUrl}/api`, {
    tags:    { path: '/api' },
    timeout: '5s',
  });

  const ok = check(res, {
    'status is 200':         (r) => r.status === 200,
    'body has version field': (r) => r.json('version') !== undefined,
  });

  if (!ok) {
    console.error(`[VU ${__VU}] Request failed: ${res.status} — ${res.body}`);
  }

  // Track which version is responding — validates canary traffic shifting.
  if (res.status === 200) {
    const body = res.json();
    if (body && body.version === 'v1') {
      v1Requests.add(1);
      versionSeen.add(false);
    } else if (body && body.version === 'v2') {
      v2Requests.add(1);
      versionSeen.add(true);
    }
  }

  // ── /healthz every 10th request ──────────────────────────────────────────
  if (__ITER % 10 === 0) {
    const hres = http.get(`${baseUrl}/healthz`, {
      tags:    { path: '/healthz' },
      timeout: '2s',
    });
    check(hres, {
      'healthz 200': (r) => r.status === 200,
    });
  }

  // Think time: realistic ~50ms between requests per VU.
  sleep(0.05);
}

// ── Teardown: print version distribution ─────────────────────────────────────
export function handleSummary(data) {
  // Write machine-readable JSON for verify-zero-downtime.sh.
  const out = JSON.stringify(data, null, 2);
  return {
    'tests/k6/results/summary.json': out,
    stdout: textSummary(data),
  };
}

// Minimal text summary — k6 built-in textSummary is only available in newer
// versions via import. This fallback keeps it compatible with k6 v0.46+.
function textSummary(data) {
  const m    = data.metrics;
  const fail = m['http_req_failed']  ? m['http_req_failed'].values.rate  : 'n/a';
  const p95  = m['http_req_duration'] ? m['http_req_duration'].values['p(95)'] : 'n/a';
  const p99  = m['http_req_duration'] ? m['http_req_duration'].values['p(99)'] : 'n/a';
  return [
    '',
    '══════════════════════════════════════════════',
    '  Zero-Downtime Load Test — Deploy Window',
    '══════════════════════════════════════════════',
    `  Error rate : ${(fail * 100).toFixed(4)}%   (target: 0.0000%)`,
    `  p95 latency: ${p95.toFixed(1)}ms            (target: <200ms)`,
    `  p99 latency: ${p99.toFixed(1)}ms`,
    '══════════════════════════════════════════════',
    '',
  ].join('\n');
}
