# Observability Q&A Bank

These questions are the ones I've actually been asked / would ask. SRE/Platform interviews always probe the three pillars (metrics, logs, traces), Prometheus internals, and SLOs. Sloppy answers here disqualify candidates fast.

## How to use

Say each answer out loud, 60-second ceiling. Be ready to whiteboard the Prometheus pull model, OTel collector pipeline, or an SLO error budget calculation.

---

## Concepts & Pillars

**Q1. What are the three pillars of observability?**
Metrics (numeric time series, aggregatable, low cardinality). Logs (high-cardinality discrete events, full context, expensive at scale). Traces (request-scoped causal chains across services). Pillars are complementary — metrics for "is something wrong?", traces for "where?", logs for "what exactly happened?".

**Q2. Difference between monitoring and observability?**
Monitoring: predefined dashboards/alerts for known failure modes ("is X up?"). Observability: ability to ask arbitrary questions about system state from outside ("why is p99 latency degraded for tenant Y?"). Observability requires high-cardinality, structured data and exploratory tooling.

**Q3. What is cardinality and why does it matter?**
Number of unique label/dimension combinations. High cardinality = more time series = more memory + storage + slower queries. Adding `user_id` to a metric label can explode series. Prometheus rule of thumb: <10M active series per server.

**Q4. RED vs USE methods?**
RED (services): Rate (requests/sec), Errors (failed/sec), Duration (latency distribution). USE (resources): Utilization, Saturation, Errors. Use RED for request-driven services, USE for nodes/disks/queues.

**Q5. What are golden signals (SRE book)?**
Latency, traffic, errors, saturation. Per-service quartet that tells you if a service is healthy. Aligns with RED + saturation.

---

## Prometheus

**Q6. Explain Prometheus architecture.**
Prometheus server scrapes /metrics endpoints on a configurable interval, stores in local TSDB, evaluates recording/alerting rules. Alertmanager handles alert deduplication and routing. Exporters expose third-party systems (node-exporter, kube-state-metrics). Pull model with service discovery.

**Q7. Why pull instead of push?**
Easier to monitor that targets are up (scrape failure = down). Centralized config of what to scrape. No client-side state. Better for trusted environments. Push (via Pushgateway) reserved for batch jobs that don't live long enough to be scraped.

**Q8. What are the four metric types?**
Counter (monotonically increasing — requests_total). Gauge (up/down — temperature, queue_depth). Histogram (bucketed counts + sum + count, server-side aggregation). Summary (client-side quantiles, can't aggregate across instances).

**Q9. Histogram vs Summary?**
Histogram: pre-defined buckets, aggregatable across instances via histogram_quantile(), more efficient on client. Summary: client-side quantiles (φ-quantiles), accurate but NOT aggregatable. Always prefer Histogram for distributed services.

**Q10. What does `rate()` do?**
Per-second average rate of increase over a time window: `rate(http_requests_total[5m])`. Handles counter resets. Always wrap counters in rate() before alerting/graphing — raw counters are useless.

**Q11. rate() vs irate() vs increase()?**
rate(): smoothed average over window (use for alerting). irate(): instant rate from last 2 samples (use for fast-moving graphs, noisy for alerts). increase(): total change over window (= rate × seconds).

**Q12. Explain recording rules.**
Pre-compute expensive queries, write result as new time series. Speeds up dashboards, used for SLO calculations. Naming convention: `level:metric:operation`, e.g., `service:http_requests:rate5m`.

**Q13. How do you alert on a 5xx spike?**
```text
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
  / sum(rate(http_requests_total[5m])) by (service) > 0.05
```
Trigger when 5xx ratio exceeds 5% over 5m. Add `for: 10m` to avoid flapping.

**Q14. What's a label vs a metric name?**
Metric name describes what you're measuring (`http_requests_total`). Labels are dimensions (`method="GET", status="200", path="/api"`). Each unique label combo = separate time series.

**Q15. Why is Prometheus federation tricky?**
Federating raw series doesn't scale. Use it only for hierarchical aggregates (sum across regions). For long-term storage and global query, use Thanos/Cortex/Mimir/VictoriaMetrics.

**Q16. Prometheus storage retention defaults?**
15 days local TSDB. Tune via `--storage.tsdb.retention.time` and `--storage.tsdb.retention.size`. For long term: remote_write to Thanos/Mimir or use VictoriaMetrics.

**Q17. What is service discovery in Prometheus?**
Auto-discover scrape targets from Kubernetes, Consul, EC2, files, DNS. K8s SD types: pod, service, endpoints, node, ingress. Used with relabeling to filter and decorate targets.

**Q18. Explain relabeling.**
Transform/filter labels at scrape time. Source labels → action (replace, keep, drop, labelmap, hashmod). Used to drop noisy targets, rename labels, derive new ones from metadata.

---

## Grafana & Dashboards

**Q19. What makes a good dashboard?**
Top: SLO/error budget at-a-glance. Middle: golden signals (RED). Bottom: drill-downs (per-host, per-endpoint). Consistent units, sensible Y-axis ranges, links to related dashboards. Avoid the "Grafana wall of charts" — dashboards should answer questions.

**Q20. Templating variables — when to use them?**
Make dashboards reusable across services/namespaces/clusters. `$service`, `$namespace` populated from Prometheus label values. Reduces dashboard sprawl.

**Q21. How do you avoid alert fatigue?**
Alert on symptoms (user-facing pain), not causes. Use multi-window multi-burn-rate for SLOs. Tier severity (page vs ticket vs ignore). Auto-resolve. Postmortem flapping alerts and tune them.

---

## Logs

**Q22. Push vs pull for logs?**
Logs almost always pushed (Fluentbit/Vector → Loki/Elasticsearch/Splunk) — too high volume, too bursty for pull. Apps write to stdout, container runtime captures, agents ship.

**Q23. Why structured logging?**
JSON logs are parseable, queryable, and aggregatable. Free-form strings require regex parsing at ingest, brittle. Always use a structured logger (zap, logrus, structlog) with consistent fields (trace_id, user_id, request_id).

**Q24. How do you correlate logs with traces?**
Inject trace_id and span_id from the OTel context into every log line. Dashboards link from a span to its logs. Without this, you spend forever grepping by timestamp.

**Q25. Loki vs Elasticsearch?**
Loki: indexes only labels (Prometheus-style), stores log content compressed in object storage. Cheap, scales horizontally, less powerful queries (LogQL). Elasticsearch: full-text inverted index, expensive but powerful. Loki for high-volume cheap logs, ES when full-text search is essential.

**Q26. What's a sampling strategy for logs?**
Tail-based sampling: keep all logs for failed/slow requests, sample 1% of successful. Reduces cost without losing debug power. Implement at agent (Vector) or app level.

---

## OpenTelemetry & Tracing

**Q27. What is OpenTelemetry?**
CNCF standard for telemetry: API + SDK + protocol (OTLP) + collector. Vendor-neutral instrumentation. Replaces OpenTracing + OpenCensus. Generates metrics, logs, traces from one SDK.

**Q28. What is the OTel collector?**
Standalone agent/gateway with three pipeline stages: Receivers (OTLP, Prometheus, jaeger) → Processors (batch, attributes, sampling) → Exporters (Tempo, Jaeger, Prometheus, OTLP). Decouples instrumentation from backends.

**Q29. Trace vs span vs context?**
Span: single operation (HTTP call, DB query) with start/end, attributes, status. Trace: tree of spans for one request. Context: trace_id + span_id propagated across process boundaries via W3C TraceContext headers.

**Q30. How does context propagation work in HTTP?**
W3C TraceContext: `traceparent` and `tracestate` headers. Server extracts incoming trace_id, creates child span, passes context to client calls (which inject same headers). Auto-instrumentation does this for popular libraries.

**Q31. Head sampling vs tail sampling?**
Head: decide at trace start (deterministic %, e.g., 1%). Cheap, fast, but might miss the failed traces you need. Tail: decide after full trace assembled (keep errors + slow). Needs collector buffering, more complex but smarter.

**Q32. Why is high-cardinality tracing better than logs?**
A trace gives you the entire request flow with attributes — far richer than scattered logs. With wide events (Honeycomb-style), one event per span replaces thousands of log lines.

**Q33. Jaeger vs Tempo vs Zipkin?**
Jaeger: mature, search by trace_id + tags. Tempo: cheap, search only by trace_id (forces metric/log correlation), Grafana-native. Zipkin: oldest, simpler model. Pick Tempo if cost-sensitive and using Grafana stack.

---

## SLOs & Error Budgets

**Q34. SLI vs SLO vs SLA?**
SLI (indicator): measurement (% requests under 200ms). SLO (objective): internal target (99.9% of requests under 200ms over 28d). SLA (agreement): external contract with consequences. SLI < SLO < SLA always.

**Q35. How do you choose SLIs?**
Pick what users feel: availability (success rate), latency (p95/p99), correctness (data freshness). Avoid system metrics (CPU, mem) as SLIs — they're causes, not symptoms.

**Q36. What is an error budget?**
1 - SLO. 99.9% SLO = 0.1% budget = 43.2 min/month of allowed unavailability. When budget is healthy, ship features fast. When burned, freeze releases and fix reliability.

**Q37. Multi-window multi-burn-rate alerting?**
Page when burn rate threatens monthly budget: e.g., 14.4× burn over 1h AND 5min (fast burn, paging) OR 6× burn over 6h AND 30min (sustained). Reduces noise vs raw threshold alerts. Standard SRE workbook pattern.

**Q38. How do you measure availability for an event-driven system?**
Pick a representative SLI: % messages processed within N seconds, % messages without error. Don't conflate "consumer up" with "users happy" — backlog can grow with healthy consumers.

---

## Production Patterns

**Q39. Where do you draw the line between metrics and logs?**
Metrics for things you want to alert on or graph (numeric, low cardinality). Logs for forensic detail (high cardinality, rare query). If you find yourself grepping logs for counts, promote to a metric.

**Q40. What is exemplar-based observability?**
Attach trace_id to histogram buckets so you can jump from "p99 latency spike" graph to a specific slow trace. Connects metrics → traces. Supported in Prometheus + Grafana + OTel.

**Q41. How do you instrument a new service?**
Auto-instrument first (OTel auto-instrumentation, Prometheus client lib defaults). Add business metrics (orders/sec, cart_abandons). Structured logs with trace_id. Define SLIs and SLOs before going live. Dashboard with golden signals.

**Q42. What's a runbook and why does every alert need one?**
Step-by-step diagnosis + remediation for an alert. Linked from the alert itself. Prevents on-call from rediscovering tribal knowledge at 3am. Update after every incident.
