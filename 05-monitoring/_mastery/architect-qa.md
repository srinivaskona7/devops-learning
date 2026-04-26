# Architect Q&A — Monitoring at Scale

50+ questions a senior observability engineer should answer in an interview or design review. Each answer aims at the WHY and the trade-off, not just the WHAT.

---

## Section A — Metrics & Cardinality

### Q1. Define cardinality and why it matters in Prometheus.

Cardinality is the number of unique label-value combinations for a metric. Each unique combination is a separate time series stored in the TSDB. A metric `http_requests_total{method, status, path}` with 5 methods, 50 statuses, and 10000 paths yields 2.5M series. Prometheus memory is roughly 3 KB per active series; that one metric costs ~7.5 GB of head RAM. Cardinality blowup is the #1 cause of Prometheus OOMs.

### Q2. What strategy do you use for high-cardinality data such as user IDs?

Move it out of metrics. Three layers:
1. **Metrics** keep low-cardinality labels (service, route, status_class).
2. **Logs** carry the per-user detail; query with LogQL for the rare "what did user X see?" question.
3. **Traces** carry per-request spans, sampled.

Use exemplars to jump from a metric chart to a representative trace, then to logs. Never put user_id, request_id, or email as a Prometheus label.

### Q3. How do you find the worst offender of cardinality?

```
topk(10, count by (__name__)({__name__=~".+"}))
```
or `prometheus_tsdb_symbol_table_size_bytes`, or the `/api/v1/status/tsdb` endpoint which lists `seriesCountByMetricName` and `labelValueCountByLabelName`.

### Q4. Recording rules — when and why?

A recording rule precomputes a query and writes the result as a new series. Use them when:
- The same expression is in many dashboards or alerts.
- The query is expensive (multi-minute range over many series).
- You want consistent SLI definitions across teams.

Trade-off: recording rules add series. Don't compute things nobody queries.

### Q5. Native histograms vs classic bucket histograms.

Classic histograms create one series per `le` bucket; 10 buckets × 1000 routes = 10000 series. Native histograms (Prometheus 2.40+) store a single float-encoded sparse histogram per series, dynamically bucketed. They cut cardinality 10–100× and improve quantile accuracy. The catch: client SDK support is still uneven, and remote-write receivers must speak the new protocol.

### Q6. Counter resets — how does `rate()` handle them?

`rate()` and `increase()` detect monotonic decreases and treat them as a counter reset (process restart). They extrapolate based on the slope before the reset. This is why you must not put non-monotonic values in counters; use a gauge instead.

### Q7. `rate()` vs `irate()` — when to use each?

`rate()` averages across the lookback window — smooth, good for alerts. `irate()` uses the last two samples — sensitive, good for graphs of fast-moving data. Never use `irate()` in alerting; one bad scrape will trigger you.

### Q8. Why does my `rate()` return 0 when the value is clearly increasing?

Lookback window too short for the scrape interval. Rule of thumb: range vector window must be at least 4× the scrape interval. With a 30 s scrape, use `rate(...[2m])` minimum.

---

## Section B — Storage & Federation

### Q9. Compare Mimir, Thanos, and Cortex.

| Property | Thanos | Cortex | Mimir |
|----------|--------|--------|-------|
| Architecture | Sidecar + object store | Microservices | Microservices fork of Cortex |
| Ingest | Prom writes locally, sidecar uploads | Remote-write to ingesters | Remote-write to ingesters |
| HA | Sidecar dedupe at query time | Replication factor | Replication factor |
| Query | Querier fans out | Query frontend + queriers | Same as Cortex, faster |
| Best for | Existing Prom installs | Multi-tenant SaaS | Modern multi-tenant, Grafana-aligned |

Mimir is what most new deployments pick today. Thanos wins when you want minimal change to existing Prometheus servers.

### Q10. When do you federate Prometheus?

Three legitimate cases:
1. **Hierarchical aggregation**: cluster-level Prom scrapes job-level Prom for cluster-wide rollups.
2. **Cross-cluster query**: a global Prom pulls a curated subset of metrics (`match[]={__name__=~"slo:.*"}`).
3. **Compliance segmentation**: keep raw data in one zone, aggregates in another.

Anti-pattern: federating *all* metrics — that is what remote_write to Mimir/Thanos is for.

### Q11. Remote-write tuning at scale.

Key params: `queue_config.max_samples_per_send` (default 2000, raise to 10000+), `max_shards` (default 200, raise to thousands), `capacity` (in-memory buffer per shard). Watch `prometheus_remote_storage_samples_pending` — sustained growth means under-provisioned receiver.

### Q12. How does Prometheus achieve HA?

Run two identical Prom replicas with `external_labels: replica: A/B`. Alertmanager dedupes alerts via fingerprint. For querying, Thanos sidecar `--query.replica-label=replica` or Mimir's HA tracker drops dupes at ingest based on the configured cluster/replica labels.

### Q13. What is the WAL and why does it matter?

Write-Ahead Log — every sample is appended to disk before going into the head block. Crash-safe; on restart, Prom replays the WAL into memory. Long replay = long startup; for 5M+ series replay can take 10+ minutes. Mitigate with WAL compression and faster disks.

### Q14. Block compaction — what does it do and what can go wrong?

Prometheus writes 2-hour TSDB blocks, then compacts them into larger blocks (up to 31 days head retention default). Compaction reduces index size and query overhead. Failures: out-of-order samples, disk full mid-compaction, mismatched block schemas after upgrade. Watch `prometheus_tsdb_compactions_failed_total`.

### Q15. Multi-tenant Prometheus — how?

Vanilla Prometheus is single-tenant. Use Mimir or Cortex with the `X-Scope-OrgID` header — every read/write carries a tenant ID, and the storage path is partitioned by tenant. Per-tenant limits (max series, ingestion rate) prevent noisy neighbors.

---

## Section C — Logs

### Q16. How do you control log volume cost?

Five levers, in order of impact:
1. **Drop debug in prod** at the SDK or sidecar.
2. **Sample repetitive lines** (1 of N for known patterns).
3. **Strip large fields** (HTTP body, stack traces in non-error).
4. **Structured JSON** so you index labels, not raw text.
5. **Tier storage** — hot SSD 7 days, cold S3 30 days, glacier beyond.

Loki's chunked object-storage model already wins on cost vs Elasticsearch by 10×.

### Q17. Why is Loki cheaper than ELK?

Loki indexes only labels, not log content. The body is gzipped chunks in S3. Elasticsearch builds an inverted index on every word — great for full-text search but storage- and CPU-heavy. The trade: LogQL searches scan chunks, so wide queries are slower than ES.

### Q18. Loki cardinality — same problem as Prom?

Yes. Each unique label combination becomes a stream, and each stream has its own chunk path. Putting `request_id` as a label kills Loki the same way it kills Prometheus. Keep labels low (service, env, level, host); put high-cardinality fields inside the line as JSON and use `| json` parsing in LogQL.

### Q19. LogQL example for error rate per service.

```
sum by (service) (
  rate({env="prod"} |= "ERROR" [5m])
)
```

### Q20. Log-derived metrics — when?

When you need to alert on something only present in logs (e.g., a string from a third-party library). Use `metric.counter` recording rules in Loki Ruler or the OTel `logstometrics` connector. Cheaper than scraping a metrics endpoint you don't control.

### Q21. Vector vs Fluent Bit vs Promtail vs OTel Collector.

| Agent | Strength | Weakness |
|-------|----------|----------|
| Promtail | Simplest for Loki | Loki-only |
| Fluent Bit | Tiny footprint, mature | Complex Lua transforms |
| Vector | Fast, VRL transform language | Newer ecosystem |
| OTel Collector | Vendor-neutral, all signals | Heavier, more config |

For greenfield, OTel Collector. For "just ship logs to Loki", Promtail.

---

## Section D — Tracing

### Q22. Trace sampling at 1M RPS — what is the strategy?

Head sampling cannot make smart decisions (you commit before knowing if the request errored). Solution: **tail sampling** in OTel Collector. Pipeline:

1. All spans go to a load-balanced collector tier (`loadbalancing` exporter, hashed by trace ID so all spans of one trace land on the same instance).
2. Tail sampler holds spans in memory for N seconds.
3. Policy: keep 100% of errors, 100% of slow (> p99), 1% of rest.
4. Drop the rest before exporting to Tempo.

Result: 99% storage savings, all interesting traces kept.

### Q23. Why must all spans of one trace go to the same tail-sampler?

Sampling decisions need the whole trace. If span A lands on collector-1 and span B on collector-2, neither has full picture and they decide independently — you get partial traces. The `loadbalancing` exporter solves this by routing on `trace_id`.

### Q24. Context propagation — how does it work?

Each request carries a `traceparent` header (W3C standard): `00-<trace-id>-<parent-span-id>-<flags>`. Each service reads it, creates a child span, and forwards a new `traceparent` downstream. Without propagation, traces fracture into single-service blobs.

### Q25. Tempo vs Jaeger.

Tempo stores spans in object storage with no index — query by trace ID is O(1), search by attribute requires the new TraceQL backend or a metrics-generator/Loki link. Jaeger has a built-in index — richer search, higher storage cost. Tempo wins on cost at scale; Jaeger wins for low-volume teams that need full-text trace search.

### Q26. What is span linking and when do you use it?

A span can link to spans in other traces (causally related but not parent-child). Common in fan-out batching: a job span links to the original request spans that triggered the batch.

### Q27. Exemplars — what are they?

A scalar metric sample annotated with a trace ID. In Grafana, click a spike on a histogram → jump to the trace that caused it. Requires histogram metrics emitted by an instrumented client (Prometheus client libs ≥ 1.0) and Tempo as the linked datasource.

---

## Section E — OpenTelemetry

### Q28. Describe a production OTel Collector topology.

Two-tier:
- **Agent tier**: DaemonSet on every node, collects local logs/metrics/traces, adds host attributes, batches, forwards.
- **Gateway tier**: Deployment, scaled horizontally, does heavy work — tail sampling, attribute scrubbing, multi-backend fan-out.

Agents are stateless; gateways may need stateful tail sampling (sticky routing). Use `loadbalancing` exporter agent → gateway.

### Q29. Why a gateway tier and not just agents?

- Centralized policy (sampling, PII scrubbing) without redeploying every node.
- Backend credentials live in one place.
- Agents stay light; heavy CPU work moves off the data plane.
- Gateway can buffer during backend outages.

### Q30. OTel Collector config anatomy.

Three sections: receivers (otlp, prometheus, filelog), processors (batch, memory_limiter, attributes, tail_sampling), exporters (otlphttp, prometheusremotewrite, loki). Tied together in `service.pipelines.{traces,metrics,logs}`. Order matters: `memory_limiter` first, `batch` last.

### Q31. SDK vs auto-instrumentation — which to ship?

Auto for fast wins (zero-code Java agent, Python `opentelemetry-instrument`). Manual SDK for the 20% of business spans that auto can't see (queue handlers, custom workers). Always tag spans with `service.name`, `deployment.environment`, `service.version`.

### Q32. What is OTLP and why does it matter?

OpenTelemetry Protocol — gRPC and HTTP encoding for all three signals. Vendor-neutral. Switching backend is a config change, not a re-instrumentation. Most modern backends (Tempo, Mimir, Loki, Honeycomb, Datadog) accept OTLP natively.

---

## Section F — Alerting & Routing

### Q33. Alertmanager routing tree at scale — design?

```yaml
route:
  receiver: default
  group_by: [alertname, cluster]
  routes:
    - matchers: [team=payments]
      receiver: pagerduty-payments
      routes:
        - matchers: [severity=warning]
          receiver: slack-payments
    - matchers: [team=infra]
      receiver: pagerduty-infra
```

Rules:
- Page only on critical, Slack on warning, ticket on info.
- `group_by` reduces noise; bad grouping = alert storm.
- `repeat_interval` 4h is sensible; shorter and people mute you.

### Q34. Alert grouping vs deduplication — difference?

Dedup removes identical alerts from HA replicas (same fingerprint). Grouping combines related but distinct alerts into one notification. Both run in Alertmanager.

### Q35. Why `for:` on alert rules?

Suppresses transient blips. `expr` must be true continuously for the `for:` duration before firing. A 1-second CPU spike at scrape time should not page you. Common: `for: 5m` for slow-burn, `for: 2m` for fast-burn.

### Q36. What is a multi-window multi-burn-rate SLO alert?

Two alerts running together:
- **Fast**: 5 min window, error rate > 14× SLO budget = page (catches incidents).
- **Slow**: 1 hour window, error rate > 6× = page (catches sustained degradation).

Both must fire together to reduce false positives. Documented in Google SRE Workbook chapter 5.

### Q37. Symptom vs cause alerting.

Alert on what users feel (latency, error rate). Don't alert on disk 80% full unless it correlates with user impact. Cause-based alerts page you about non-incidents.

### Q38. How do you stop alert fatigue?

- Move noisy alerts to ticket/Slack only.
- Delete alerts that have never been actionable.
- Audit weekly: every paged alert needs a runbook URL.
- Track "page → action" ratio per service; > 30% noise = redesign.

### Q39. On-call workflow with Grafana OnCall.

Schedule → escalation policy → integration (Alertmanager webhook). Each alert hits an integration, OnCall maps to a route, route picks the on-caller from the schedule. Acknowledge stops escalation; resolve closes. Post-incident review attaches to the alert group.

### Q40. Silences vs inhibitions.

Silence = manually mute matching alerts for a window (planned maintenance). Inhibition = if alert A fires, suppress alert B (e.g., cluster down → suppress every pod-down alert in that cluster).

---

## Section G — SLOs

### Q41. Define SLI, SLO, SLA, error budget.

- SLI = measurement (success rate, latency p99).
- SLO = target for the SLI (99.9%).
- SLA = contract with the customer with money attached.
- Error budget = 100% − SLO, expressed as time or events.

### Q42. How do you pick an SLO target?

Look at past 30-day performance, set the SLO slightly tighter than current achievable, with stakeholder buy-in. Don't promise 99.999% if you cannot measure it. Each extra nine costs ~10× the engineering effort.

### Q43. Burn-rate math example.

SLO 99.9% over 30 days = budget 43.2 minutes. Burn rate 1 = consuming budget exactly at SLO speed. Burn rate 14.4 over 1 hour exhausts 2% of monthly budget — that's the standard fast-burn page threshold.

### Q44. SLO architecture in a multi-team org.

Each team owns its services and SLIs. A central platform team provides the recording rules (`slo:availability_ratio:rate5m`), the alert templates, and the Grafana dashboards. Teams configure thresholds in a self-serve repo (Sloth, OpenSLO).

### Q45. Sloth / OpenSLO — what do they give you?

Declarative SLO definitions. You write a YAML with the SLI and target; the tool generates Prometheus recording rules and burn-rate alerts. Stops every team from reinventing the math.

---

## Section H — Grafana

### Q46. Dashboard performance — top tips.

- One panel per query; avoid dashboard variables that expand into 50 series.
- Set `min step` on time series panels.
- Use recording rules for any expression a dashboard runs > 100×/day.
- Cache at the data source (Mimir query frontend has results cache).
- Avoid `=~` regex selectors when an exact match works.

### Q47. Variables — chained vs independent.

Chained variables (`$cluster` → `$namespace` → `$pod`) reduce option count but add load on the datasource. For 10000+ pods, prefer text input over dropdown.

### Q48. How do you template a dashboard for N services?

One dashboard, `$service` variable populated by `label_values(up{job=~".+"}, service)`. All panels filter by `{service=~"$service"}`. Add a "service overview" link from each row.

---

## Section I — Cost & Operations

### Q49. Telemetry budget — how do you set one?

Three buckets per environment: ingest GB/day, active series, retention days. Each team gets a quota. Enforce with Mimir limits (`max_global_series_per_user`) and Loki ingestion limits. Bill internally — the team that emits 80% of metrics pays 80% of cost.

### Q50. Pull vs push for metrics.

Pull (Prometheus): central system controls cadence, easy to detect down targets (`up == 0`), works only when targets are reachable. Push (StatsD, OTLP): targets behind NAT or short-lived (Lambda, batch jobs) need push. Prometheus Pushgateway exists but is meant for batch jobs only.

### Q51. How do you observe the observability stack?

Self-monitoring: Prometheus scrapes itself, exposes `prometheus_tsdb_*`, `prometheus_engine_query_duration_seconds`. Run a second Prom (the "meta" Prom) that scrapes the primary — gives you alerts even when primary is unhealthy. Same for Alertmanager (`alertmanager_notifications_failed_total`).

### Q52. What metrics tell you a Prometheus is in trouble?

- `prometheus_tsdb_head_series` rising fast → cardinality explosion.
- `prometheus_tsdb_wal_corruptions_total > 0` → disk issue.
- `prometheus_remote_storage_samples_pending` rising → downstream slow.
- `process_resident_memory_bytes` near the pod limit.
- `prometheus_engine_query_duration_seconds{quantile="0.99"} > 30` → query overload.

### Q53. Capacity planning for 1M active series.

- Memory: ~3 GB head + 2 GB query.
- CPU: 2-4 cores for ingest at 100k samples/s.
- Disk: ~1.3 bytes per sample; 100k samples/s × 86400 = ~11 GB/day; with 15-day retention ≈ 165 GB plus 2× headroom.
- Network: ~50 Mbps remote-write at typical compression.

### Q54. Disaster recovery for telemetry.

Telemetry is replaceable, not precious. RTO matters more than RPO. Strategy:
- Object storage (S3) for blocks → cross-region replication.
- Two AZ ingesters with replication factor 3.
- Daily backup of Grafana SQLite/Postgres.
- Runbook to spin up a stand-in cluster from S3 in < 1 hour.

### Q55. What does "observability-driven development" mean?

Instrument while writing the code, not after the incident. Every new endpoint ships with: a counter, a histogram, structured logs, span attributes, and one alert. The PR template asks for it. Reviewers reject PRs without telemetry.

---

## Closing principle

> Observability is a product. Treat it like one — with users (your engineers), an SLO (dashboard load time), a roadmap, and a budget.
