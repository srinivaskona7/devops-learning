/**
 * k6 smoke test — URL Shortener (Project 02)
 *
 * Flow:
 *   1. POST /api/shorten  → capture code
 *   2. GET  /:code        → assert 302 redirect
 *
 * Targets:
 *   - p95 < 150ms
 *   - error rate 0.00%
 *   - 100 VUs, 2 minutes
 *
 * Run:
 *   k6 run tests/k6/smoke.js
 *   k6 run --env BASE_URL=http://staging.example.com tests/k6/smoke.js
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// ── Custom metrics ──────────────────────────────────────────────────────
const shortenDuration = new Trend('shorten_duration', true);
const redirectDuration = new Trend('redirect_duration', true);
const errorRate       = new Rate('error_rate');
const shortenCount    = new Counter('shorten_count');

// ── Config ───────────────────────────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'http://localhost';

// A pool of well-known URLs to shorten (so we exercise duplicate-detection too)
const TARGET_URLS = [
  'https://github.com/torvalds/linux',
  'https://docs.docker.com/compose/',
  'https://fastapi.tiangolo.com/',
  'https://www.postgresql.org/docs/16/',
  'https://nginx.org/en/docs/',
  'https://k6.io/docs/',
  'https://example.com/path/to/resource',
  'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/302',
];

// ── Load profile ─────────────────────────────────────────────────────────
export const options = {
  scenarios: {
    steady_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },   // ramp up
        { duration: '90s', target: 100 },   // hold
        { duration: '30s', target: 0   },   // ramp down (included in 2m window)
      ],
    },
  },
  thresholds: {
    // Primary SLOs
    http_req_duration:  ['p(95)<150'],    // p95 < 150ms
    http_req_failed:    ['rate<0.01'],    // < 1% errors (target 0%)
    // Custom metric SLOs
    shorten_duration:   ['p(95)<200'],
    redirect_duration:  ['p(95)<100'],
    error_rate:         ['rate<0.01'],
  },
};

// ── Main test function ───────────────────────────────────────────────────
export default function () {
  const targetUrl = TARGET_URLS[Math.floor(Math.random() * TARGET_URLS.length)];

  let code = null;

  group('shorten', () => {
    const payload = JSON.stringify({ url: targetUrl });
    const params  = { headers: { 'Content-Type': 'application/json' } };

    const res = http.post(`${BASE_URL}/api/shorten`, payload, params);
    shortenDuration.add(res.timings.duration);
    shortenCount.add(1);

    const ok = check(res, {
      'shorten: status 201':     (r) => r.status === 201,
      'shorten: has code field': (r) => {
        try { return typeof JSON.parse(r.body).code === 'string'; }
        catch { return false; }
      },
      'shorten: has short_url':  (r) => {
        try { return JSON.parse(r.body).short_url.startsWith(BASE_URL); }
        catch { return false; }
      },
    });

    errorRate.add(!ok);

    if (res.status === 201) {
      try { code = JSON.parse(res.body).code; } catch { /* ignore */ }
    }
  });

  if (code) {
    group('redirect', () => {
      // We do NOT follow the redirect (maxRedirects: 0) so we measure only
      // the API lookup time, not the target server round-trip.
      const res = http.get(`${BASE_URL}/${code}`, { redirects: 0 });
      redirectDuration.add(res.timings.duration);

      const ok = check(res, {
        'redirect: status 302':          (r) => r.status === 302,
        'redirect: Location header set': (r) => !!r.headers['Location'],
        'redirect: Location matches target': (r) =>
          r.headers['Location'] === targetUrl ||
          r.headers['Location'] === targetUrl + '/',
      });

      errorRate.add(!ok);
    });
  }

  // Minimal think time — realistic browser pacing
  sleep(Math.random() * 0.5 + 0.1);
}

// ── Setup — warm up DB connection pool ───────────────────────────────────
export function setup() {
  const res = http.get(`${BASE_URL}/ready`);
  if (res.status !== 200) {
    throw new Error(`Stack not ready before test — /ready returned ${res.status}`);
  }
  console.log(`[setup] stack ready — starting load against ${BASE_URL}`);
}

// ── Teardown — summary ────────────────────────────────────────────────────
export function teardown(data) {
  console.log('[teardown] test complete — check thresholds in summary above');
}
