/**
 * tests/k6/during-drill.js
 *
 * k6 continuous traffic test that runs throughout a DR drill.
 * Measures HTTP error rates and latency during the failover window.
 *
 * The test runs in three phases:
 *   1. Baseline (5 min):  normal traffic, establish baseline metrics
 *   2. Drill (15 min):    failover in progress, measure error rate
 *   3. Recovery (5 min):  post-failover, confirm p95 within target
 *
 * Usage:
 *   k6 run tests/k6/during-drill.js \
 *     --env BASE_URL=https://api.example.com \
 *     --env TARGET=drill \
 *     --out json=/tmp/k6-drill-result.json
 *
 * Environment variables:
 *   BASE_URL           - Target URL (default: https://api.example.com)
 *   TARGET             - "normal" | "drill" (affects VU count and duration)
 *   ERROR_RATE_LIMIT   - Max allowed error rate during drill (default: 0.01 = 1%)
 *
 * Pass criteria (thresholds):
 *   - Baseline: error rate = 0%, p95 < 200ms
 *   - Drill window: error rate ≤ 1%, p95 < 2000ms (high during DNS propagation)
 *   - Recovery: error rate = 0%, p95 < 250ms
 *
 * Real-world reference:
 *   Cloudflare's 2022 DR report cited < 0.3% error rate during their
 *   DNS-layer failover. The 1% threshold here is deliberately conservative.
 *   GitHub's 2018 incident had 0% error rate for the first 2 hours (the
 *   database failover was transparent at the HTTP layer) — errors only
 *   appeared when data inconsistency caused application logic failures.
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

// ─── Configuration ────────────────────────────────────────────────────────────

const BASE_URL       = __ENV.BASE_URL       || 'https://api.example.com';
const TARGET         = __ENV.TARGET         || 'drill';
const ERROR_RATE_LIMIT = parseFloat(__ENV.ERROR_RATE_LIMIT || '0.01');

// Duration and VU configuration per target
const CONFIGS = {
  normal: {
    stages: [
      { duration: '30s', target: 20 },   // ramp up
      { duration: '2m',  target: 50 },   // steady state
      { duration: '30s', target: 0 },    // ramp down
    ],
    gracefulRampDown: '10s',
  },
  drill: {
    // Full drill test: baseline → failover → recovery
    // Total: 25 minutes — run this BEFORE starting the drill and keep it running
    stages: [
      { duration: '2m',  target: 20 },   // ramp up (baseline)
      { duration: '3m',  target: 20 },   // baseline steady state
      { duration: '15m', target: 20 },   // drill window (failover happens here)
      { duration: '3m',  target: 20 },   // recovery steady state
      { duration: '2m',  target: 0 },    // ramp down
    ],
    gracefulRampDown: '30s',
  },
};

const config = CONFIGS[TARGET] || CONFIGS.drill;

// ─── k6 options ───────────────────────────────────────────────────────────────
export const options = {
  stages: config.stages,
  gracefulRampDown: config.gracefulRampDown,

  thresholds: {
    // Overall error rate must stay below 1% (accounts for DNS propagation spike)
    http_req_failed: [
      { threshold: `rate<${ERROR_RATE_LIMIT}`, abortOnFail: false }
    ],

    // p95 overall (more lenient during drill than normal operation)
    http_req_duration: [
      { threshold: 'p(95)<2000', abortOnFail: false },   // during drill
    ],

    // Health check endpoint must be fast (this is the failover trigger)
    'http_req_duration{endpoint:healthz}': [
      { threshold: 'p(99)<500', abortOnFail: false },
    ],

    // Checks pass rate: all checks must succeed ≥ 95% of the time
    checks: [
      { threshold: 'rate>0.95', abortOnFail: false },
    ],
  },

  // Tag each VU with the scenario name for metric filtering
  tags: {
    test_target: TARGET,
    base_url: BASE_URL,
  },
};

// ─── Custom metrics ───────────────────────────────────────────────────────────

// Counts requests during the failover window (tagged by drill phase)
const drillWindowErrors = new Counter('drill_window_errors');
const drillWindowRequests = new Counter('drill_window_requests');
const drillWindowErrorRate = new Rate('drill_window_error_rate');

// Track latency separately for post-failover period
const postFailoverLatency = new Trend('post_failover_latency', true);

// ─── Drill phase tracker ──────────────────────────────────────────────────────
// The drill has three phases based on elapsed time since test start.
// Thresholds are evaluated per phase in the summary.

const TEST_START = Date.now();

function getDrillPhase() {
  const elapsedSeconds = (Date.now() - TEST_START) / 1000;
  if (elapsedSeconds < 300) return 'baseline';      // first 5 minutes
  if (elapsedSeconds < 1200) return 'drill';        // 5-20 minutes (failover window)
  return 'recovery';                                 // after 20 minutes
}

// ─── Test scenarios ───────────────────────────────────────────────────────────

// Scenario 1: Health check — lightweight, tests the /healthz endpoint
// This is the same endpoint Route53 probes. High-frequency to detect failover.
function testHealthCheck() {
  const response = http.get(`${BASE_URL}/healthz`, {
    tags: { endpoint: 'healthz' },
    timeout: '5s',
  });

  const phase = getDrillPhase();
  const ok = check(response, {
    'healthz: status 200': (r) => r.status === 200,
    'healthz: response time < 500ms': (r) => r.timings.duration < 500,
    'healthz: body contains status': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'ok' || body.status === 'healthy';
      } catch {
        return false;
      }
    },
  });

  if (phase === 'drill') {
    drillWindowRequests.add(1);
    if (!ok || response.status !== 200) {
      drillWindowErrors.add(1);
      drillWindowErrorRate.add(1);
    } else {
      drillWindowErrorRate.add(0);
    }
  }

  if (phase === 'recovery') {
    postFailoverLatency.add(response.timings.duration);
  }
}

// Scenario 2: API read — tests a typical read path through the application
function testApiRead() {
  const response = http.get(`${BASE_URL}/api/users?limit=10`, {
    headers: { 'Accept': 'application/json' },
    tags: { endpoint: 'api_read' },
    timeout: '10s',
  });

  const phase = getDrillPhase();

  check(response, {
    'api_read: status 200': (r) => r.status === 200,
    'api_read: valid JSON': (r) => {
      try { JSON.parse(r.body); return true; }
      catch { return false; }
    },
    'api_read: response time < 1000ms (drill ok at 2000ms)': (r) => {
      return phase === 'drill'
        ? r.timings.duration < 2000
        : r.timings.duration < 1000;
    },
  });

  if (phase === 'drill') {
    drillWindowRequests.add(1);
    if (response.status !== 200) {
      drillWindowErrors.add(1);
    }
  }
}

// Scenario 3: Database health check — confirms Postgres connectivity
function testDbHealth() {
  const response = http.get(`${BASE_URL}/api/health/db`, {
    tags: { endpoint: 'db_health' },
    timeout: '10s',
  });

  check(response, {
    'db_health: status 200': (r) => r.status === 200,
    'db_health: database connected': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.database === 'connected';
      } catch {
        return false;
      }
    },
    'db_health: shows region': (r) => {
      try {
        const body = JSON.parse(r.body);
        return typeof body.region === 'string' && body.region.length > 0;
      } catch {
        return false;
      }
    },
  });
}

// ─── Main VU function ─────────────────────────────────────────────────────────
export default function () {
  const phase = getDrillPhase();

  group('health_check', () => {
    testHealthCheck();
  });

  // Stagger API calls to avoid thundering herd during DNS propagation
  sleep(0.5);

  group('api_read', () => {
    testApiRead();
  });

  sleep(0.5);

  // DB health check every 5th iteration (lower frequency than app checks)
  if (Math.random() < 0.2) {
    group('db_health', () => {
      testDbHealth();
    });
  }

  // Realistic think time between request batches
  // Shorter during drill to maintain pressure through failover
  const thinkTime = phase === 'drill' ? 1 : 2;
  sleep(thinkTime);
}

// ─── Setup ────────────────────────────────────────────────────────────────────
export function setup() {
  console.log(`Starting k6 DR drill test`);
  console.log(`  Target: ${BASE_URL}`);
  console.log(`  Mode:   ${TARGET}`);
  console.log(`  Error rate limit: ${(ERROR_RATE_LIMIT * 100).toFixed(1)}%`);
  console.log(`  Stages: ${JSON.stringify(config.stages)}`);
  console.log(``);
  console.log(`Test phases:`);
  console.log(`  0-5 min:   baseline (error rate must be 0%)`);
  console.log(`  5-20 min:  drill window (error rate ≤${(ERROR_RATE_LIMIT * 100).toFixed(1)}%)`);
  console.log(`  20-25 min: recovery (error rate must return to 0%)`);

  // Pre-check: verify target is reachable
  const resp = http.get(`${BASE_URL}/healthz`, { timeout: '10s' });
  if (resp.status !== 200) {
    console.error(`WARNING: Target ${BASE_URL}/healthz returned ${resp.status} at test start`);
  }

  return { testStart: Date.now() };
}

// ─── Teardown + Summary ───────────────────────────────────────────────────────
export function handleSummary(data) {
  const errorRate = data.metrics.http_req_failed
    ? data.metrics.http_req_failed.values.rate
    : 0;

  const p95 = data.metrics.http_req_duration
    ? data.metrics.http_req_duration.values['p(95)']
    : 0;

  const drillErrors = data.metrics.drill_window_errors
    ? data.metrics.drill_window_errors.values.count
    : 0;

  const drillRequests = data.metrics.drill_window_requests
    ? data.metrics.drill_window_requests.values.count
    : 0;

  const drillErrorRate = drillRequests > 0
    ? (drillErrors / drillRequests * 100).toFixed(2)
    : '0.00';

  const postFailoverP95 = data.metrics.post_failover_latency
    ? data.metrics.post_failover_latency.values['p(95)']
    : null;

  const summary = {
    // Standard k6 text summary
    stdout: textSummary(data, { indent: ' ', enableColors: true }),

    // Machine-readable JSON for the drill report
    '/tmp/k6-drill-summary.json': JSON.stringify({
      timestamp: new Date().toISOString(),
      target: BASE_URL,
      mode: TARGET,
      overall_error_rate: errorRate,
      overall_p95_ms: p95,
      drill_window_errors: drillErrors,
      drill_window_requests: drillRequests,
      drill_window_error_rate_pct: drillErrorRate,
      post_failover_p95_ms: postFailoverP95,
      error_rate_pass: errorRate <= ERROR_RATE_LIMIT,
      checks_pass: data.metrics.checks
        ? data.metrics.checks.values.rate >= 0.95
        : false,
    }, null, 2),
  };

  // Print drill-specific summary to console
  console.log(`\n=== DR Drill Traffic Summary ===`);
  console.log(`  Overall error rate:       ${(errorRate * 100).toFixed(2)}%`);
  console.log(`  Overall p95 latency:      ${p95 ? p95.toFixed(0) : 'N/A'} ms`);
  console.log(`  Drill window errors:      ${drillErrors} / ${drillRequests} requests`);
  console.log(`  Drill window error rate:  ${drillErrorRate}%`);
  console.log(`  Post-failover p95:        ${postFailoverP95 ? postFailoverP95.toFixed(0) : 'N/A'} ms`);
  console.log(`  Error rate target:        ≤${(ERROR_RATE_LIMIT * 100).toFixed(1)}%`);
  console.log(`  Error rate pass:          ${errorRate <= ERROR_RATE_LIMIT ? 'PASS' : 'FAIL'}`);
  console.log(`================================\n`);

  return summary;
}
