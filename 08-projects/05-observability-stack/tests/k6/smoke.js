import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

// ── Custom metrics ─────────────────────────────────────────────────────────
const errorRate   = new Rate("custom_error_rate");
const slowLatency = new Trend("slow_endpoint_duration", true);

// ── Config ─────────────────────────────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

export const options = {
  stages: [
    { duration: "30s", target: 10  },   // ramp-up
    { duration: "60s", target: 50  },   // steady load
    { duration: "60s", target: 100 },   // stress
    { duration: "30s", target: 0   },   // ramp-down
  ],
  thresholds: {
    // Four Golden Signals pass criteria
    http_req_duration:      ["p(95)<500"],   // p95 < 500ms (slow endpoint excluded via tags)
    http_req_failed:        ["rate<0.35"],   // < 35% errors (flaky is intentionally ~30%)
    custom_error_rate:      ["rate<0.35"],
    "http_req_duration{endpoint:fast}":  ["p(95)<50"],   // fast < 50ms
    "http_req_duration{endpoint:slow}":  ["p(95)<3000"], // slow < 3s
  },
};

// ── Test scenarios ─────────────────────────────────────────────────────────
export default function () {
  const headers = { "Content-Type": "application/json" };

  // ── /fast ────────────────────────────────────────────────────────────────
  {
    const res = http.get(`${BASE_URL}/fast`, { headers, tags: { endpoint: "fast" } });
    const ok = check(res, {
      "/fast status 200":   (r) => r.status === 200,
      "/fast body has key": (r) => r.json("endpoint") === "fast",
    });
    errorRate.add(!ok);
  }

  sleep(0.05);

  // ── /slow ────────────────────────────────────────────────────────────────
  {
    const res = http.get(`${BASE_URL}/slow`, { headers, tags: { endpoint: "slow" }, timeout: "5s" });
    const ok = check(res, { "/slow status 200": (r) => r.status === 200 });
    slowLatency.add(res.timings.duration);
    errorRate.add(!ok);
  }

  sleep(0.1);

  // ── /flaky ───────────────────────────────────────────────────────────────
  {
    const res = http.get(`${BASE_URL}/flaky`, { headers, tags: { endpoint: "flaky" } });
    // flaky returns 500 ~30% — that's expected, don't count as threshold error
    check(res, { "/flaky responded": (r) => r.status === 200 || r.status === 500 });
  }

  sleep(0.05);

  // ── /cpu ─────────────────────────────────────────────────────────────────
  {
    const res = http.get(`${BASE_URL}/cpu`, { headers, tags: { endpoint: "cpu" }, timeout: "3s" });
    const ok = check(res, { "/cpu status 200": (r) => r.status === 200 });
    errorRate.add(!ok);
  }

  sleep(0.2);
}

// ── Setup: verify service is up ───────────────────────────────────────────
export function setup() {
  const res = http.get(`${BASE_URL}/healthz`);
  if (res.status !== 200) {
    throw new Error(`Service not ready: ${res.status} — is the stack running? (make up)`);
  }
  console.log(`obs-demo reachable at ${BASE_URL}`);
}

// ── Teardown: summary ─────────────────────────────────────────────────────
export function handleSummary(data) {
  const p95  = data.metrics.http_req_duration?.values?.["p(95)"]?.toFixed(0) ?? "N/A";
  const errP = (data.metrics.http_req_failed?.values?.rate * 100)?.toFixed(2) ?? "N/A";
  console.log(`\n── Smoke Test Summary ──────────────────────────────`);
  console.log(`  p95 latency : ${p95} ms`);
  console.log(`  error rate  : ${errP}%`);
  console.log(`  threshold   : p95 < 500ms, errors < 35%`);
  return {};
}
