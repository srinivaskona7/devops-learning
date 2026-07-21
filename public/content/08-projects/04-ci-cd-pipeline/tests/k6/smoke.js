import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('error_rate');
const helloLatency = new Trend('hello_latency', true);

export const options = {
  // Smoke test: moderate VU count, short duration.
  // Intent: prove the service handles concurrent load without crashing.
  stages: [
    { duration: '10s', target: 10 },  // ramp up
    { duration: '20s', target: 30 },  // steady state
    { duration: '5s',  target: 0  },  // ramp down
  ],
  thresholds: {
    // Pipeline fails if any of these are violated.
    'http_req_duration{name:healthz}': ['p(95)<50'],   // healthz must be fast
    'http_req_duration{name:hello}':   ['p(95)<200'],  // hello can do more work
    'http_req_failed':                 ['rate<0.01'],  // < 1% errors
    'error_rate':                      ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  // Test /healthz — should always respond in < 5ms (just returns JSON)
  const healthz = http.get(`${BASE_URL}/healthz`, {
    tags: { name: 'healthz' },
  });

  check(healthz, {
    'healthz status 200':     (r) => r.status === 200,
    'healthz body ok':        (r) => r.json('status') === 'ok',
    'healthz content-type':   (r) => r.headers['Content-Type'].includes('application/json'),
  });

  errorRate.add(healthz.status !== 200);

  // Test /ready — readiness probe endpoint
  const ready = http.get(`${BASE_URL}/ready`, {
    tags: { name: 'ready' },
  });

  check(ready, {
    'ready status 200': (r) => r.status === 200,
    'ready body ready': (r) => r.json('status') === 'ready',
  });

  // Test /api/hello — business logic endpoint
  const hello = http.get(`${BASE_URL}/api/hello`, {
    tags: { name: 'hello' },
  });

  helloLatency.add(hello.timings.duration);

  check(hello, {
    'hello status 200':         (r) => r.status === 200,
    'hello has message':        (r) => r.json('message') !== '',
    'hello has hostname':       (r) => r.json('hostname') !== '',
    'hello has timestamp':      (r) => r.json('timestamp') !== '',
    'hello content-type json':  (r) => r.headers['Content-Type'].includes('application/json'),
  });

  errorRate.add(hello.status !== 200);

  sleep(0.1); // 100ms think time — realistic browser pacing
}

export function handleSummary(data) {
  // Write summary JSON for CI artifact upload
  return {
    'tests/results.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: '  ', enableColors: true }),
  };
}

// Inline text summary (avoids k6/x/summary import requirement)
function textSummary(data, opts) {
  const indent = opts.indent || '';
  const lines = [];
  lines.push(`${indent}--- k6 smoke test summary ---`);
  lines.push(`${indent}Total requests: ${data.metrics.http_reqs.values.count}`);
  lines.push(`${indent}Error rate:     ${(data.metrics.error_rate.values.rate * 100).toFixed(2)}%`);
  if (data.metrics['http_req_duration{name:hello}']) {
    const d = data.metrics['http_req_duration{name:hello}'].values;
    lines.push(`${indent}Hello p50:      ${d['p(50)'].toFixed(1)}ms`);
    lines.push(`${indent}Hello p95:      ${d['p(95)'].toFixed(1)}ms`);
  }
  return lines.join('\n') + '\n';
}
