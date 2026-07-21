# QA Plan — Project 05: Observability Stack
## Correlation Test: One request ID in three pillars

**Scope:** Verify that a single `trace_id` appears simultaneously in a Prometheus exemplar, a Loki log line, and a Tempo trace span — proving the three-pillar correlation guarantee.

**Prerequisites:**
- `make up` has completed without errors
- Grafana accessible at `http://localhost:3000` (admin / obs-demo-secret)
- `kubectl -n obs-demo get pods` — all pods Running

---

## Phase 1 — Unit: Application instrumentation

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| 1.1 | Service starts and exports OTLP | `curl -s http://localhost:8000/healthz` | `{"status":"ok"}` |
| 1.2 | Prometheus metrics endpoint present | `curl -s http://localhost:8000/metrics \| grep demo_requests_total` | counter line returned |
| 1.3 | Structured log contains trace_id | `kubectl -n obs-demo logs deploy/obs-demo \| grep trace_id` | `trace_id=<hex>` field present |
| 1.4 | All 4 demo endpoints respond | `for e in fast slow flaky cpu; do curl -s http://localhost:8000/$e; done` | JSON body from each |
| 1.5 | /flaky returns 500 ~30% | `for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/flaky; done` | 4–10 lines showing `500` |

---

## Phase 2 — Integration: OTel Collector pipeline

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| 2.1 | Collector health check | `curl -s http://localhost:13133/` | `{"status":"Server available"}` |
| 2.2 | Collector zpages (traces received) | `curl -s http://localhost:55679/debug/tracez` | HTML page with span counts |
| 2.3 | Prometheus remote-write accepted | `curl -s http://localhost:9090/api/v1/query?query=demo_requests_total` | JSON with `result` array non-empty |
| 2.4 | Loki ingestion | `curl -s "http://localhost:3100/loki/api/v1/query_range?query={service_name%3D\"obs-demo\"}" \| jq '.data.result \| length'` | `>= 1` |
| 2.5 | Tempo ingestion | `curl -s "http://localhost:3100/api/search?service=obs-demo" \| jq '.traces \| length'` | `>= 1` |

---

## Phase 3 — Correlation: Three-pillar trace_id linkage

**This is the core test.** Execute in order.

### Step 3A — Generate a traced request and capture the trace_id

```bash
# Trigger a slow request (long enough for all three to record)
TRACE_RESPONSE=$(curl -sv http://localhost:8000/slow 2>&1)
# The trace_id is emitted to logs. Capture it:
TRACE_ID=$(kubectl -n obs-demo logs deploy/obs-demo --since=30s \
  | grep '"slow endpoint"' \
  | grep -oP 'trace_id=\K[a-f0-9]{32}' \
  | tail -1)
echo "Captured trace_id: $TRACE_ID"
```

**Pass criteria:** `$TRACE_ID` is a 32-character hex string.

---

### Step 3B — Verify trace_id in Loki (Pillar 2: Logs)

```bash
curl -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={service_name=\"obs-demo\"} |= \"$TRACE_ID\"" \
  --data-urlencode "limit=5" \
  | jq '.data.result[0].values[0][1]'
```

**Pass criteria:** JSON response contains the log line with matching `trace_id`.

---

### Step 3C — Verify trace_id in Tempo (Pillar 3: Traces)

```bash
curl -s "http://localhost:3100/api/traces/$TRACE_ID" \
  | jq '.batches[0].scopeSpans[0].spans[0].name'
```

**Pass criteria:** Returns `"slow-handler"` or `"GET /slow"`.

---

### Step 3D — Verify exemplar in Prometheus (Pillar 1: Metrics)

```bash
# Query the histogram with exemplars
curl -s -H "Accept: application/openmetrics-text" \
  "http://localhost:9090/api/v1/query_exemplars?query=demo_request_duration_seconds_bucket" \
  | jq '.data[] | select(.labels.endpoint == "/slow") | .exemplars[] | .labels.trace_id' \
  | head -5
```

**Pass criteria:** At least one exemplar `trace_id` matches `$TRACE_ID`.

---

### Step 3E — Grafana UI correlation test (manual)

1. Open Grafana → **Four Golden Signals** dashboard.
2. Locate a data point spike on the **p95 latency** panel.
3. Click a diamond-shaped exemplar point → **View in Tempo**.
4. Confirm the Tempo trace opens with the matching `trace_id`.
5. In the Tempo trace panel click **Logs for this span** → Loki opens with the same `trace_id`.
6. In the Tempo trace panel click **Metrics** → Prometheus opens the service rate graph.

**Pass criteria:** All three navigations succeed without manual copy-paste of the `trace_id`.

---

## Phase 4 — Performance

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| 4.1 | Smoke test — baseline | `make perf` | p95 < 500ms, errors < 35% |
| 4.2 | /fast endpoint only | `k6 run --env BASE_URL=http://localhost:8000 tests/k6/smoke.js` | p95{endpoint:fast} < 50ms |
| 4.3 | Collector memory under load | `kubectl -n obs-demo top pod -l app=otel-collector` | < 512Mi |
| 4.4 | Loki ingest lag | `rate({service_name="obs-demo"}[1m])` in Grafana | > 0 during load |

---

## Phase 5 — SLO validation

| # | Test | PromQL | Pass Criteria |
|---|------|--------|---------------|
| 5.1 | Current availability | `1 - (sum(rate(demo_requests_total{status=~"5.."}[1h])) / sum(rate(demo_requests_total[1h])))` | >= 0.70 (flaky ~30% by design) |
| 5.2 | Burn-rate alert fires | Trigger: `for i in $(seq 100); do curl -s http://localhost:8000/flaky; done` | SLO Burn-Rate dashboard shows burn rate > 14.4x |
| 5.3 | Error budget panel | Open **SLO Burn-Rate** dashboard | "Time to exhaustion" stat card shows hours, not "NaN" |

---

## Phase 6 — Chaos

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| 6.1 | Kill obs-demo pod during load | `kubectl -n obs-demo delete pod -l app=obs-demo --grace-period=0` while `make demo-slow` runs | k6 shows < 5% extra errors during pod restart window |
| 6.2 | Kill OTel collector | `kubectl -n obs-demo delete pod -l app=otel-collector` | App continues serving; metrics resume within 60s of pod restart |
| 6.3 | Prometheus compaction | `kubectl -n obs-demo exec -it prometheus-0 -- kill -SIGTERM 1` | Prometheus restarts cleanly; data from before restart visible |

---

## Acceptance criteria summary

| Pillar | Signal | Tool | Verified? |
|--------|--------|------|-----------|
| Metrics | Rate, errors, latency, saturation | Prometheus + Grafana | [ ] |
| Logs | Structured with trace_id field | Loki | [ ] |
| Traces | Spans with service graph | Tempo | [ ] |
| Correlation | Same trace_id in all three | Grafana exemplar links | [ ] |
| SLO | Burn-rate panel renders | Grafana | [ ] |
| Chaos | Pod loss < 5% extra errors | k6 + kubectl | [ ] |
