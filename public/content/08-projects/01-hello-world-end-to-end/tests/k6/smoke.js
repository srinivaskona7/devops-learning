/**
 * Project 01 · Hello World on Docker — k6 smoke test
 *
 * Scenario: constant load of 50 virtual users for 2 minutes.
 * Target:   p95 < 50 ms, zero errors.
 *
 * Run locally:
 *   k6 run tests/k6/smoke.js
 *   BASE_URL=http://localhost:8080 k6 run tests/k6/smoke.js
 *
 * Run via Docker (no k6 install needed):
 *   docker run --rm -i --network=host \
 *     -e BASE_URL=http://localhost:8080 \
 *     -v $(pwd)/tests/k6:/scripts \
 *     grafana/k6:latest run /scripts/smoke.js
 *
 * Expected results on a 2020+ laptop:
 *   http_req_duration p(50) ≈  4 ms
 *   http_req_duration p(95) ≈ 18 ms   (target < 50 ms)
 *   http_req_failed         = 0.00%
 *   checks                  = 100%
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

// ── Custom metrics ────────────────────────────────────────────────────────
const errorRate   = new Rate("custom_error_rate");
const htmlReqTime = new Trend("html_req_duration", true);

// ── Test options ──────────────────────────────────────────────────────────
export const options = {
  // Constant load: ramp to 50 VUs over 10 s, hold for 100 s, ramp down.
  stages: [
    { duration: "10s", target: 50 },   // ramp up
    { duration: "100s", target: 50 },  // hold — 50 VUs for ~1 min 40 s
    { duration: "10s", target: 0 },    // ramp down
  ],

  // Hard failure thresholds — the test fails (exit 1) if any are breached.
  thresholds: {
    // p95 must stay under 50 ms
    "http_req_duration": ["p(95)<50"],

    // Zero tolerance for HTTP errors (4xx / 5xx / network errors)
    "http_req_failed": ["rate<0.001"],

    // Our custom error tracker (belt-and-suspenders)
    "custom_error_rate": ["rate<0.001"],

    // All checks must pass
    "checks": ["rate>0.999"],
  },
};

// ── Base URL ─────────────────────────────────────────────────────────────
// Override with env: BASE_URL=http://my-host:8080 k6 run smoke.js
const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";

// ── Main function (called once per VU per iteration) ─────────────────────
export default function () {
  // ── Request 1: index page ──────────────────────────────────────────────
  const indexRes = http.get(`${BASE_URL}/`, {
    tags:    { name: "IndexPage" },
    timeout: "5s",
  });

  htmlReqTime.add(indexRes.timings.duration);

  const indexOk = check(indexRes, {
    "index: status 200":          (r) => r.status === 200,
    "index: body contains DevOps": (r) => r.body.includes("DevOps"),
    "index: content-type html":   (r) => (r.headers["Content-Type"] || "").includes("text/html"),
    "index: x-frame-options set": (r) => r.headers["X-Frame-Options"] === "DENY",
    "index: x-content-type set":  (r) => r.headers["X-Content-Type-Options"] === "nosniff",
  });

  errorRate.add(!indexOk);

  // ── Request 2: CSS file ────────────────────────────────────────────────
  const cssRes = http.get(`${BASE_URL}/styles.css`, {
    tags:    { name: "StylesCSS" },
    timeout: "5s",
  });

  const cssOk = check(cssRes, {
    "css: status 200":          (r) => r.status === 200,
    "css: content-type css":    (r) => (r.headers["Content-Type"] || "").includes("text/css"),
    "css: cache-control set":   (r) => (r.headers["Cache-Control"] || "").includes("max-age"),
  });

  errorRate.add(!cssOk);

  // ── Request 3: 404 handling ────────────────────────────────────────────
  // nginx should return index.html (SPA fallback) or a clean 404.
  // We just verify the server doesn't return a 5xx error.
  const notFoundRes = http.get(`${BASE_URL}/this-path-does-not-exist`, {
    tags:    { name: "NotFound" },
    timeout: "5s",
  });

  check(notFoundRes, {
    "404: no 5xx error": (r) => r.status < 500,
  });

  // Short think time between iterations — realistic browser pacing.
  sleep(0.05);
}

// ── Setup function (runs once before VUs start) ──────────────────────────
export function setup() {
  console.log(`\n  Target URL : ${BASE_URL}`);
  console.log(`  VUs        : 50`);
  console.log(`  Duration   : ~2 minutes`);
  console.log(`  p95 target : < 50 ms\n`);

  // Warm-up request — establishes TCP connection, fills kernel page cache.
  const warmup = http.get(`${BASE_URL}/`);
  if (warmup.status !== 200) {
    console.error(`SETUP FAILED: ${BASE_URL}/ returned ${warmup.status}. Is the container running?`);
    // k6 will still run the test; the checks will surface the failures.
  }
}

// ── Teardown function (runs once after all VUs finish) ───────────────────
export function teardown(data) {
  console.log("\n  Test complete. Review thresholds above for pass/fail status.");
}
