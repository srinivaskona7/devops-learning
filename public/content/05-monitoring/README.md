<p class="hero monitoring"><h1>05 · Monitoring & <em>observability</em></h1><p class="tagline">Twelve lessons that turn "the site feels slow" into a graph, a query, and a fix — before the CEO tweets.</p></p>

## Roadmap — your learning path

<div class="roadmap" markdown>

<div class="stop" data-step="1" markdown>
#### Three pillars
Metrics say *what*. Logs say *why*. Traces say *where*. Pick the right lens.
</div>

<div class="stop" data-step="2" markdown>
#### Prometheus architecture
A pull-based TSDB with a scrape loop, a WAL, and a retention clock.
</div>

<div class="stop" data-step="3" markdown>
#### PromQL essentials
`rate`, `histogram_quantile`, `sum by (...)` — the three verbs that run SRE.
</div>

<div class="stop" data-step="4" markdown>
#### Recording & alerting rules
Pre-compute the expensive query. Fire when the budget burns, not when CPU wiggles.
</div>

<div class="stop" data-step="5" markdown>
#### Grafana dashboards
Variables, templating, annotations — one dashboard for every environment.
</div>

<div class="stop" data-step="6" markdown>
#### Loki for logs
Index labels, not lines. Cheap, fast — until you index a user ID.
</div>

<div class="stop" data-step="7" markdown>
#### Tempo / Jaeger traces
A span model, tail-based sampling, and the first tool that answers "where did the latency go?"
</div>

<div class="stop" data-step="8" markdown>
#### OpenTelemetry SDK
One API, every language, three signals — plus baggage and resource semconv.
</div>

<div class="stop" data-step="9" markdown>
#### OTel Collector
Receivers → processors → exporters. The universal telemetry pipeline.
</div>

<div class="stop" data-step="10" markdown>
#### SLO / SLI / error budget
The SRE math that turns "the site is slow" into a policy and a budget.
</div>

<div class="stop" data-step="11" markdown>
#### Alertmanager routing
Inhibition, grouping, silencing, escalation — the nervous system of on-call.
</div>

<div class="stop" data-step="12" markdown>
#### Cardinality discipline
One bad label kills your cluster. Learn to count before you label.
</div>

</div>

---

## 1. The three pillars — metrics, logs, traces

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** At 03:00 a payment service is on fire. Your dashboard shows error rate climbing, but the graph doesn't tell you *why*. You grep logs — 40,000 lines per second, `ERROR` everywhere, no clue which request failed where. You need three lenses, not one. Metrics answer "is it broken?", logs answer "what exploded?", traces answer "where in the call chain?". Pick the wrong lens and you burn the error budget debugging the wrong thing.

<span class="stage thinking">Thinking</span>

**Mental model.** Three signals, three storage shapes, three query languages — all correlated by a shared `trace_id` and timestamp.

```mermaid
flowchart LR
  App[Service] -->|counters, gauges, histograms| M["Metrics<br/>Prometheus TSDB"]
  App -->|structured events| L["Logs<br/>Loki / Elastic"]
  App -->|spans| T["Traces<br/>Tempo / Jaeger"]
  M -->|what?| G[Grafana]
  L -->|why?| G
  T -->|where?| G
  G -->|correlate via trace_id| SRE((SRE))
```

<div class="grid cards" markdown>

-   :material-chart-line:{ .lg .middle } **Metrics (Prometheus)**

    ---
    Time-series of numeric measurements scraped via `/metrics`. RED method: Rate, Errors, Duration per service.

-   :material-text-box-multiple:{ .lg .middle } **Logs (Loki)**

    ---
    Indexed by labels only — no full-text index. Query with LogQL. Push via Promtail or Alloy.

-   :material-vector-polyline:{ .lg .middle } **Traces (Tempo)**

    ---
    Distributed trace = tree of spans. W3C TraceContext propagates trace-id across services. Tempo stores, Grafana visualizes.

-   :material-bell-alert:{ .lg .middle } **Alerting (Alertmanager)**

    ---
    Routes alerts to PagerDuty/Slack/email. Inhibition, silences, group-wait prevent alert storms.

</div>

- **Metrics** = numeric aggregates sampled every 15s — cheap per cardinality, expensive per label.
- **Logs** = full-fidelity events — expensive per volume, easy to search.
- **Traces** = causal spans across services — expensive per 100% sampling, priceless for latency attribution.
- **Events** (the fourth signal) = deploys, config changes, autoscale actions — annotate timelines.
- **Correlation ID** (`trace_id`) glues all three together. Without it, you are guessing.

<span class="stage execution">Execution</span>

**Run it yourself.** Spin a tiny stack and emit one signal per pillar.

```bash
# Metrics: scrape /metrics
curl -s http://localhost:9090/metrics | head -20

# Logs: tail a structured log
kubectl -n prod logs -l app=checkout --tail=20 | jq .

# Traces: fetch a trace by ID
curl -s http://localhost:3200/api/traces/7f3e1a... | jq '.batches[].scopeSpans[].spans[] | {name,duration}'
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> curl -s localhost:9090/metrics | head
<span class="comment"># HELP http_requests_total HTTP requests processed</span>
<span class="comment"># TYPE http_requests_total counter</span>
<span class="comment">http_requests_total{method="GET",status="200"} 43219</span>
<span class="comment">http_requests_total{method="POST",status="500"} 87</span>

<span class="prompt">$</span> kubectl logs -l app=checkout --tail=2 | jq .
<span class="comment">{ "ts": "2026-04-27T03:02:11Z", "level": "error",</span>
<span class="comment">  "trace_id": "7f3e1a...", "msg": "db connect timeout" }</span>

<span class="prompt">$</span> curl -s localhost:3200/api/traces/7f3e1a... | jq '.batches | length'
<span class="comment">4   # 4 services participated in this request</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">one lens only</span>
logs-only debugging
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">three pillars wired</span>
metrics + logs + traces emit
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">root cause in minutes</span>
p99 spike → log error → span stuck on DB
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Honeycomb**, the engineering team coined "observability driven development." Their own checkout API used metrics to detect a 4x p99 spike, jumped to logs to find `pg: too many connections`, and used a trace to prove the retry storm started in the cart service — not the database. Time to root cause: 8 minutes. With logs alone, prior incidents had taken 2+ hours.
</div>

</div>

---

## 2. Prometheus architecture — pull model, TSDB, retention

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** SoundCloud in 2012 ran hundreds of services and drowned in push-based metric systems — broken agents, UDP packet loss, no service discovery. They built Prometheus to invert the model: Prometheus reaches out and scrapes `/metrics` on a schedule, so a dead target is visible as `up == 0`. The architecture is three parts — scraper, TSDB, query engine — and every production issue you'll hit maps to one of them.

<span class="stage thinking">Thinking</span>

**Mental model.** Prometheus is a single binary. It discovers targets, pulls samples, appends them to a Write-Ahead Log, compacts 2-hour blocks, and deletes anything past retention.

```mermaid
flowchart LR
  SD["Service Discovery<br/>K8s, EC2, file"] --> SC["Scrape loop<br/>every 15s"]
  SC -->|HTTP GET /metrics| APP[Target]
  SC --> WAL["(WAL<br/>head block)"]
  WAL -->|every 2h| BLK["(Block<br/>chunks + index)"]
  BLK -->|compact| BIG["(Compacted<br/>24h block)"]
  BIG -->|retention 15d| DEL[Deleted]
  QE["Query Engine<br/>PromQL"] --> WAL
  QE --> BLK
  API[HTTP API] --> QE
```

- **Pull, not push.** Prometheus initiates every scrape. Down target = `up == 0`, no lost samples pretending to be zero.
- **Single-node by default.** No leader election, no consensus. Horizontal scale = federation, Thanos, or Mimir.
- **WAL first, blocks later.** Every sample lands in the Write-Ahead Log before being indexed. A crash replays the WAL on restart.
- **Retention is time-based, not size-based.** `--storage.tsdb.retention.time=15d` deletes anything older than 15 days.
- **The TSDB is delta-encoded and XOR-compressed.** Typical sample cost: ~1.3 bytes on disk.

<span class="stage execution">Execution</span>

**Run it yourself.** Start Prometheus, point it at itself, and inspect the TSDB.

```bash
# 1. Minimal config
cat > /tmp/prom.yml <<'EOF'
global: { scrape_interval: 15s }
scrape_configs:
  - job_name: prometheus
    static_configs: [{ targets: ['localhost:9090'] }]
EOF

# 2. Run Prometheus with 2h retention for quick test
docker run --rm -d --name prom -p 9090:9090 \
  -v /tmp/prom.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:v2.54.1 \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.retention.time=2h

# 3. Verify targets are UP
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, health}'

# 4. See TSDB stats
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats'
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | .health'
<span class="comment">"up"</span>

<span class="prompt">$</span> curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats'
<span class="comment">{ "numSeries": 842,</span>
<span class="comment">  "numLabelPairs": 3411,</span>
<span class="comment">  "chunkCount": 842,</span>
<span class="comment">  "numSamples": 50920 }</span>

<span class="prompt">$</span> du -sh /prometheus
<span class="comment">14M  /prometheus   # ~1.3 bytes per sample</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">push agent lost samples</span>
UDP drops, no dead-target signal
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">pull scrape loop</span>
15s interval, WAL growing
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">dead target = up==0</span>
TSDB compacts, retention enforced
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At SoundCloud** (2012), the team replaced their push-based StatsD pipeline with Prometheus and cut debugging MTTR by 60%. The pull model let them detect dead scrape targets instantly (the `up` metric), and the single-binary design meant they could run it on a $50 VM per cluster instead of the 12-node Graphite cluster it replaced. Prometheus was open-sourced a year later and became the second CNCF graduated project after Kubernetes.
</div>

</div>

---

## 3. PromQL essentials — rate, histogram_quantile, aggregations

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** You have 843 metrics. At 03:00 you need to answer "what's the p99 latency of checkout per region, right now?" — and you have 30 seconds before the CEO pings Slack. Raw time series are useless. PromQL is a functional query language where three verbs — `rate`, `histogram_quantile`, and `sum by (...)` — solve 90% of every SRE question. Everything else is decoration.

<span class="stage thinking">Thinking</span>

**Mental model.** Instant vector → range vector → function → aggregation → result.

```mermaid
flowchart LR
  TS["Time series<br/>http_requests_total"] -->|range selector [5m]| RV[Range vector]
  RV -->|rate| IV["Instant vector<br/>req/sec"]
  IV -->|sum by (status)| AGG["Aggregated<br/>vector"]
  AGG -->|/ total| RATIO[Error ratio]
  HIST[_bucket series] -->|histogram_quantile 0.99| P99[p99 latency]
```

- **Counter** (ever-increasing) → always wrap in `rate()` or `increase()`. Never query raw counters.
- **Gauge** (up/down) → query directly: `node_memory_Available_bytes`.
- **Histogram** (`_bucket`, `_count`, `_sum`) → `histogram_quantile(0.99, sum by (le) (rate(..._bucket[5m])))` — the `le` label is load-bearing.
- **`sum by (label)`** keeps the label, everything else collapses. **`sum without (label)`** drops just that one.
- **Rule of thumb:** `rate[5m]` smooths noise, `rate[1m]` catches spikes — pick based on alert urgency.

<span class="stage execution">Execution</span>

**Run it yourself.** Query a live Prometheus via `promtool` or the HTTP API.

```bash
# Rate — requests per second per status code
curl -sG 'localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum by (status) (rate(http_requests_total[5m]))' | jq .

# Error ratio — 5xx divided by all (annotated)
rate(http_requests_total{job="api",status=~"5.."}[5m]) # (1)!
  /                                                      # (2)!
rate(http_requests_total{job="api"}[5m])                # (3)!
```
1. `rate()` computes per-second rate over the 5m window. `status=~"5.."` matches all 5xx codes via regex.
2. Division produces the error ratio (0.0–1.0).
3. Denominator: total request rate for the same job across all status codes.

```bash
curl -sG 'localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))' | jq .

# p99 latency — histogram_quantile is the only verb that matters
curl -sG 'localhost:9090/api/v1/query' \
  --data-urlencode 'query=histogram_quantile(0.99, sum by (le,service) (rate(http_request_duration_seconds_bucket[5m])))' | jq .

# Validate syntax without running
promtool query instant http://localhost:9090 'up'
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> promtool query instant localhost:9090 \
    'sum by (status) (rate(http_requests_total[5m]))'
<span class="comment"># {status="200"} => 847.2 @[1714180000]</span>
<span class="comment"># {status="500"} => 3.1   @[1714180000]</span>

<span class="prompt">$</span> promtool query instant localhost:9090 \
    'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'
<span class="comment"># {} => 0.284   # 284ms p99</span>

<span class="prompt">$</span> # BAD: forgot sum by (le) — result is nonsense
<span class="prompt">$</span> promtool query instant localhost:9090 \
    'histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))'
<span class="comment"># Error: vector has multiple series with le label — aggregate by (le)</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">raw counters</span>
"http_requests_total = 42M" — useless
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">rate + sum by</span>
derivatives + grouping applied
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">p99 = 284ms in us-east</span>
actionable number, regional breakdown
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Datadog**, the SRE team runs an internal PromQL clone for dogfooding. They publish a "PromQL golden path" — literally three functions (`rate`, `histogram_quantile`, `sum by`) — and a rule: any alert query that can't be expressed in those three is rejected at code review. It eliminated 70% of the "why did this alert fire?" questions in their post-incident reviews.
</div>

</div>

---

## 4. Recording + alerting rules — SLO burn-rate alerts

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** A PromQL query that takes 4 seconds to evaluate at the dashboard is fine. The same query inside an alert rule that runs every 15 seconds across 200 services will melt your Prometheus. Enter **recording rules** — pre-compute the expensive query once, store it as a new time series, query the cheap result everywhere. **Alerting rules** then fire on the result. And the most powerful alerting pattern — the multi-window burn-rate alert — only becomes tractable once recording rules exist.

<span class="stage thinking">Thinking</span>

**Mental model.** Evaluation group runs every N seconds → rules inside it execute in order → recording rules write back to TSDB → alerting rules compare the result to thresholds → Alertmanager routes.

```mermaid
flowchart LR
  TSDB[(TSDB)] --> EG["Rule group<br/>interval=30s"]
  EG --> REC["Recording rule<br/>job:http_errors:ratio5m"]
  REC -->|write back| TSDB
  EG --> ALT["Alerting rule<br/>burn_rate > 14.4"]
  ALT -->|firing| AM[Alertmanager]
  AM --> PD[PagerDuty]
  subgraph Burn-rate logic
    B1[5m window × 14.4] --> FAST[page in 4m]
    B2[1h window × 6] --> SLOW[page in 1h]
  end
```

- **Recording rules** create a new metric (`job:http_errors:ratio5m`) computed every 30s — one query, thousands of cheap reuses.
- **Naming convention:** `level:metric:operation` — e.g. `job:http_errors:ratio5m` (level=job, metric=http_errors, op=ratio5m).
- **Alerting rules** compare a value to a threshold and fire after `for:` stabilises the signal.
- **Multi-window burn-rate alerts** compare a short window (5m) and a long window (1h) against the same threshold → catches both big spikes and slow burns without flapping.
- **The `14.4` magic number** = burn the entire 30-day budget in 2 days. Google SRE book, page 119.

<div class="before-after" markdown>

**❌ Before — noisy threshold**

```yaml
- alert: HighLatency
  expr: http_request_duration_seconds > 0.1
  for: 0s
```

**✅ After — meaningful SLO-based threshold**

```yaml
- alert: HighLatency  
  expr: |
    histogram_quantile(0.99,
      rate(http_request_duration_seconds_bucket[5m])
    ) > 0.5
  for: 10m
  labels:
    severity: warning
```

</div>

<span class="stage execution">Execution</span>

**Run it yourself.** Drop this file into `/etc/prometheus/rules/slo.yml` and reload.

```yaml
groups:
  - name: slo_checkout
    interval: 30s
    rules:
      # Recording rule: precompute error ratio
      - record: job:http_errors:ratio5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))

      # Recording rule: 1h window for slow-burn
      - record: job:http_errors:ratio1h
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum by (job) (rate(http_requests_total[1h]))

      # Alerting rule: multi-window fast-burn
      - alert: SLOErrorBudgetFastBurn
        expr: |
          job:http_errors:ratio5m{job="checkout"} > (14.4 * 0.001)
          and
          job:http_errors:ratio1h{job="checkout"} > (14.4 * 0.001)
        for: 2m
        labels: { severity: page, slo: checkout }
        annotations:
          summary: "checkout burning budget 14.4x — will exhaust in 2 days"
```

=== ":material-prometheus: PrometheusRule"
    ```yaml
    groups:
    - name: api.slo
      rules:
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m])
          / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate > 1% for 5 minutes"
    ```

=== ":material-grafana: Grafana Alert"
    ```yaml
    # In Grafana UI: Alerting → Alert rules → New alert rule
    # Expression: same PromQL, threshold: IS ABOVE 0.01
    # Pending period: 5m
    # Labels: severity=critical
    ```

```bash
# Reload Prometheus rules without restart
curl -X POST localhost:9090/-/reload

# Verify rules loaded
curl -s localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | {name, type, state}'
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> curl -s localhost:9090/api/v1/rules | jq '.data.groups[0].rules[] | {name,type}'
<span class="comment">{ "name": "job:http_errors:ratio5m", "type": "recording" }</span>
<span class="comment">{ "name": "job:http_errors:ratio1h", "type": "recording" }</span>
<span class="comment">{ "name": "SLOErrorBudgetFastBurn",   "type": "alerting"  }</span>

<span class="prompt">$</span> promtool query instant localhost:9090 'job:http_errors:ratio5m{job="checkout"}'
<span class="comment"># {job="checkout"} => 0.0162     # 1.62% errors</span>
<span class="comment"># threshold: 14.4 * 0.001 = 0.0144 — FIRING</span>

<span class="prompt">$</span> curl -s localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name:.labels.alertname, state}'
<span class="comment">{ "name": "SLOErrorBudgetFastBurn", "state": "firing" }</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">flapping CPU alert</span>
"disk > 80%" pages 40x/night
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">recording rule precomputes</span>
burn rate series appears
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">single page per real incident</span>
symptom-based, budget-aware
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Google**, the SRE book's burn-rate alerting pattern (multi-window, multi-burn-rate) came out of the Ads team's 2016 on-call crisis — they were paged 50+ times per night on CPU thresholds that meant nothing. Chapter 5 of the SRE Workbook (page 109-134) codified the 14.4 / 6 / 3 / 1 burn-rate ladder. After rollout, paging volume dropped 80% and mean-time-to-acknowledge stayed under 5 minutes because every page now corresponded to a user-visible symptom.
</div>

</div>

---

## 5. Grafana dashboards — variables, templating, annotations

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** You have 12 environments (dev/stg/prod × 4 regions). You don't want 12 dashboards. You want **one** dashboard with a dropdown that rewrites every query. You also want a vertical line on the graph at the moment someone ran `kubectl apply` so "did the deploy cause this?" takes three seconds to answer instead of 30 minutes of git-blame. Variables solve environment sprawl; annotations solve causality.

<span class="stage thinking">Thinking</span>

**Mental model.** Variable is a template placeholder → picker changes value → every panel query is re-rendered → annotations overlay events on the time axis.

```mermaid
flowchart LR
  USER["User picks<br/>env=prod, region=us-east"] --> VAR["Variable<br/>$env, $region"]
  VAR --> Q["Panel query<br/>rate{env=&quot;$env&quot;, region=&quot;$region&quot;}"]
  Q --> DS["(Datasource<br/>Prometheus)"]
  DS --> PANEL[Panel renders]
  ANN["Annotation query<br/>changes_deploy_total"] --> OVER["Vertical line<br/>on time axis"]
  OVER --> PANEL
```

- **Variables** = `$env`, `$region`, `$service` — populated by a query (`label_values(up, env)`) or a static list.
- **Templating** = the variable value is string-substituted into every panel query before execution.
- **Multi-value variables** (`All` + checkboxes) expand into `env=~"prod|stg"` regex — PromQL-friendly.
- **Annotations** = time-ranged events (deploys, incidents, maintenance) rendered as vertical lines or shaded bands.
- **JSON model** lives in Grafana's DB or as a file in git — dashboards-as-code via `grafonnet` or `grizzly`.

<span class="stage execution">Execution</span>

**Run it yourself.** Provision a dashboard with a variable and an annotation.

```bash
# 1. Pull a minimal dashboard JSON
cat > /tmp/dash.json <<'EOF'
{
  "title": "Checkout SLO",
  "templating": {
    "list": [{
      "name": "env", "type": "query", "datasource": "prometheus",
      "query": "label_values(http_requests_total, env)",
      "refresh": 1, "multi": false
    }]
  },
  "annotations": {
    "list": [{
      "name": "deploys", "datasource": "prometheus",
      "expr": "changes(process_start_time_seconds{job=\"checkout\"}[1m]) > 0",
      "iconColor": "green"
    }]
  },
  "panels": [{
    "title": "Error ratio",
    "type": "timeseries",
    "targets": [{
      "expr": "sum(rate(http_requests_total{env=\"$env\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{env=\"$env\"}[5m]))"
    }]
  }]
}
EOF

# 2. Push via API
curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H 'Content-Type: application/json' \
  -d "{\"dashboard\": $(cat /tmp/dash.json), \"overwrite\": true}"

# 3. Verify variable resolves
curl -s http://admin:admin@localhost:3000/api/datasources/proxy/1/api/v1/label/env/values | jq .
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> curl -s .../api/v1/label/env/values | jq .
<span class="comment">{ "status": "success",</span>
<span class="comment">  "data": ["dev", "stg", "prod"] }</span>

<span class="prompt">$</span> # Grafana renders the variable dropdown at the top:
<span class="comment">[ env: prod ▾ ]     # changing this re-fires every panel query</span>

<span class="prompt">$</span> # Annotation query returns deploy events
<span class="comment">changes(process_start_time_seconds{job="checkout"}[1m]) > 0</span>
<span class="comment">=> 2026-04-27T02:58:14Z  (green vertical line on graph)</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">12 copy-paste dashboards</span>
drift across environments
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">single templated dashboard</span>
$env / $region variables active
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">one source of truth</span>
+ deploy lines overlay causality
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Grafana Labs**, every internal dashboard is generated from a single `grafonnet` library. The SRE team reports that a single "Service Overview" template, parameterised by `$service` + `$env`, serves 400+ microservices — one JSON file in git, auto-deployed via CI. Before templating, they had 2,100 hand-maintained dashboards and an entire Confluence page titled "Which dashboard is the real one?"
</div>

</div>

---

## 6. Loki for logs — LogQL, label cardinality trap

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** Elasticsearch indexes every word of every log line. Great for search, terrible for cost — you pay to index "the", "a", "INFO" a billion times. Loki flips the model: **index the labels, store the log lines as compressed chunks**. You get fast label-based filtering (`{app="api"}`) and grep-speed regex (`|= "timeout"`). Cost plummets 10x. But the trap is identical to Prometheus — index one high-cardinality label (user_id!) and Loki implodes.

<span class="stage thinking">Thinking</span>

**Mental model.** Log line → Promtail adds labels → sent to Loki → split into streams (one per label set) → chunked + gzipped → index points to chunks.

```mermaid
flowchart LR
  APP[App stdout] --> PT[Promtail / Alloy]
  PT -->|add labels: app, namespace, level| ING[Loki Ingester]
  ING --> S1["Stream<br/>{app=api, level=error}"]
  ING --> S2["Stream<br/>{app=api, level=info}"]
  S1 --> CHK["(Chunk<br/>gzipped 1MB)"]
  S2 --> CHK
  IDX["(BoltDB index<br/>labels → chunk IDs)"] -.-> CHK
  QRY[LogQL query] --> IDX
  IDX --> CHK --> OUT[Log lines]
```

- **A stream = unique label set.** `{app=api, level=error, pod=api-7}` is one stream. 10k pods = 10k streams × 3 levels = 30k streams.
- **LogQL** has two halves: label matcher `{app="api"}` selects streams, then line filter `|= "timeout"` greps inside.
- **Never put unbounded values in labels.** `user_id`, `request_id`, `trace_id` as labels = cardinality bomb.
- **Put them in the log body instead** — extract at query time: `{app="api"} | json | user_id="alice"`.
- **Chunks are stored in object storage** (S3, GCS) — Loki is cheap because blob storage is cheap.

<span class="stage execution">Execution</span>

**Run it yourself.** Query Loki from the CLI, both safely and dangerously.

```bash
# Safe: filter by stream label, then grep
logcli --addr=http://localhost:3100 query \
  '{app="checkout", namespace="prod"} |= "timeout"' --limit=20 --since=15m

# Extract a JSON field at query time (no label explosion)
logcli --addr=http://localhost:3100 query \
  '{app="checkout"} | json | status_code >= 500' --limit=10

# Metric from logs — error rate per pod
logcli --addr=http://localhost:3100 query \
  'sum by (pod) (rate({app="checkout"} |= "error" [5m]))'

# DANGEROUS: audit your label cardinality
logcli --addr=http://localhost:3100 series '{}' --since=1h | wc -l
# > 100k means someone put a UUID in a label
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> logcli query '{app="checkout"} |= "timeout"' --limit=3
<span class="comment">2026-04-27T03:02:11Z {app="checkout", pod="checkout-7"}</span>
<span class="comment">  ERROR db connect timeout after 5s trace_id=7f3e1a</span>
<span class="comment">2026-04-27T03:02:13Z {app="checkout", pod="checkout-7"}</span>
<span class="comment">  ERROR retry exhausted trace_id=7f3e1a</span>

<span class="prompt">$</span> logcli series '{}' --since=1h | wc -l
<span class="comment">1247   # healthy — under 10k streams</span>

<span class="prompt">$</span> # BAD: someone added user_id as a label
<span class="prompt">$</span> logcli series '{}' --since=1h | wc -l
<span class="comment">892340 # Loki is about to OOM</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">Elastic $$$</span>
3TB index, $40k/month
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">Loki chunks in S3</span>
labels indexed, lines compressed
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">$4k/month, faster grep</span>
10x cheaper, identical UX
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Grafana Labs**, Loki was born out of the 2018 Prometheus conference hallway track — David Kaltschmidt prototyped it in a weekend to prove "what if Prometheus, but for logs?" Their public Loki deployment now handles 1 petabyte/day at under 1/10 the cost of the Elasticsearch cluster it replaced. The single-biggest learning they share publicly: "we've had three cluster-down incidents, and all three were caused by someone putting a dynamic value in a label."
</div>

</div>

---

## 7. Tempo / Jaeger for traces — span model, sampling strategies

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** A single checkout request hits 14 services. Metrics say "p99 is high." Logs say "errors in 3 services." Neither tells you that Service-G's DB call took 2.1s because of a cold cache. Traces do. A trace is a tree of spans — parent/child timing, attached to a single `trace_id` that flows through every hop. Tempo and Jaeger store those trees and let you click from a metric spike straight to the slowest span.

<span class="stage thinking">Thinking</span>

**Mental model.** Each service adds a span. Spans propagate context (`trace_id` + `span_id`) via HTTP headers. Backend reassembles the tree.

```mermaid
flowchart TB
  ROOT["Span: POST /checkout<br/>service=gateway<br/>400ms"] --> A["Span: cart.get<br/>service=cart<br/>50ms"]
  ROOT --> B["Span: inventory.reserve<br/>service=inv<br/>80ms"]
  ROOT --> C["Span: payment.charge<br/>service=pay<br/>250ms ⚠️"]
  C --> C1["Span: db.query<br/>210ms ⚠️ cold cache"]
  C --> C2["Span: stripe.api<br/>40ms"]
  B --> B1["Span: redis.decr<br/>5ms"]
```

- **A span** = start time, duration, service name, operation, attributes (kv), status.
- **Trace context** = `traceparent` header (W3C) carrying `trace_id` + `span_id` across HTTP/gRPC/Kafka.
- **Head-based sampling** (decide at root): simple, but you can't keep only the slow traces.
- **Tail-based sampling** (decide at the collector after seeing the full trace): keep all errors, keep top-1% latency, drop the rest. Expensive — requires buffering whole traces.
- **Tempo stores traces in object storage**, indexed by `trace_id` only — cheap, but you query by ID or use TraceQL.

<span class="stage execution">Execution</span>

**Run it yourself.** Fetch a trace, inspect spans, find the slowest.

```bash
# 1. Fetch a trace by ID (Tempo HTTP API)
TRACE_ID=7f3e1a98b2c4d5e6
curl -s "http://localhost:3200/api/traces/$TRACE_ID" \
  | jq '.batches[].scopeSpans[].spans[] | {name, durationMs: (.endTimeUnixNano - .startTimeUnixNano)/1e6}'

# 2. TraceQL — find slow checkout traces
curl -sG http://localhost:3200/api/search \
  --data-urlencode 'q={ resource.service.name="checkout" && duration > 500ms }' \
  --data-urlencode 'limit=5' | jq .

# 3. Configure tail sampling in OTel Collector
cat > /tmp/tailsample.yaml <<'EOF'
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow
        type: latency
        latency: { threshold_ms: 500 }
      - name: sample-rest
        type: probabilistic
        probabilistic: { sampling_percentage: 1 }
EOF
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> curl -s localhost:3200/api/traces/7f3e1a | \
    jq '.batches[].scopeSpans[].spans[] | {name, ms: ((.endTimeUnixNano|tonumber) - (.startTimeUnixNano|tonumber))/1e6}'
<span class="comment">{ "name": "POST /checkout",  "ms": 400 }</span>
<span class="comment">{ "name": "cart.get",        "ms": 50  }</span>
<span class="comment">{ "name": "inventory.reserve", "ms": 80 }</span>
<span class="comment">{ "name": "payment.charge",  "ms": 250 }  ← hot spot</span>
<span class="comment">{ "name": "db.query",        "ms": 210 }  ← root cause</span>

<span class="prompt">$</span> # TraceQL: find all traces slower than 500ms
<span class="prompt">$</span> curl -sG localhost:3200/api/search \
    --data-urlencode 'q={ duration > 500ms }' | jq '.traces | length'
<span class="comment">14</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">"p99 is high somewhere"</span>
guessing game across 14 services
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">spans propagate trace_id</span>
collector reassembles tree
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">db.query = 210ms of 250ms</span>
fix: warm the cache on deploy
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Uber**, Jaeger was built in 2015 when the ride-hailing stack had ~1,500 microservices and an incident took an average of 2 hours to root-cause. After Jaeger rollout and tail sampling (keep all errors + 1% of others), MTTR dropped to 20 minutes. Uber open-sourced Jaeger in 2017; it's now a CNCF graduated project. Their tail-sampling white paper is the most-cited paper in distributed tracing.
</div>

</div>

---

## 8. OpenTelemetry SDK — auto-instrumentation, baggage, resource semconv

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** Before OTel, every vendor had its own SDK — Jaeger client, Zipkin client, New Relic agent, Datadog tracer — each requiring code rewrites when you migrated. OTel is the CNCF unification: one API, one wire protocol (OTLP), three signals (metrics, logs, traces). Auto-instrumentation hooks your framework without code changes. Baggage lets you propagate key-value context (like `tenant_id`) across service boundaries. Resource semconv standardises attribute names so `service.name` means the same thing everywhere.

<span class="stage thinking">Thinking</span>

**Mental model.** Instrument once with OTel API → SDK exports to collector → collector translates to any backend.

```mermaid
flowchart LR
  APP[App code] --> API["OTel API<br/>vendor-neutral"]
  API --> SDK["OTel SDK<br/>batcher, sampler"]
  AUTO["Auto-instrumentation<br/>agent / init-hook"] -.->|patches http, db, grpc| API
  SDK -->|OTLP gRPC/HTTP| COL[OTel Collector]
  BAG["Baggage<br/>tenant_id=acme"] -.->|propagates via header| API
  RES["Resource<br/>service.name=checkout<br/>deployment.environment=prod"] -.-> SDK
  COL --> TEMPO[Tempo]
  COL --> PROM[Prometheus]
  COL --> LOKI[Loki]
```

- **API vs SDK**: the API is the interface your code calls. The SDK is the pluggable implementation that actually emits. Library authors depend on the API only.
- **Auto-instrumentation** patches common libraries (http, grpc, pg, redis, kafka) at startup — zero code changes for 80% of telemetry.
- **Baggage** = key-value propagated in a separate header (`baggage: tenant_id=acme`). Different from span attributes: baggage crosses service boundaries automatically.
- **Resource semconv** = a contract: `service.name`, `service.version`, `deployment.environment`, `k8s.pod.name`. The OTel spec lists 400+ standard names.
- **Context propagation** uses `traceparent` (W3C) + `baggage` — never custom headers.

<span class="stage execution">Execution</span>

**Run it yourself.** Auto-instrument a Python app in 2 lines.

```bash
# 1. Install OTel auto-instrumentation for Python
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install    # installs instrumentors for detected libs

# 2. Run the app with env-based config
export OTEL_SERVICE_NAME=checkout
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=prod,service.version=1.4.2"
export OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1    # 10% sampling
opentelemetry-instrument python app.py
```

```python
# Manual span + baggage for the 20% auto can't cover
from opentelemetry import trace, baggage, context
tracer = trace.get_tracer("checkout")

def process_order(order_id, tenant):
    # Attach baggage — propagates to every downstream service
    ctx = baggage.set_baggage("tenant_id", tenant)
    with tracer.start_as_current_span("process_order", context=ctx) as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.amount_cents", 4299)
        # ... business logic ...
        span.set_status(trace.StatusCode.OK)
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> opentelemetry-instrument python app.py
<span class="comment">Instrumentations loaded: flask, requests, psycopg2, redis, grpc</span>
<span class="comment">Exporter: OTLP → http://collector:4317</span>
<span class="comment">Sampler: parentbased_traceidratio(0.1)</span>

<span class="prompt">$</span> curl -s localhost:8080/checkout/42
<span class="comment">{"ok": true}</span>

<span class="prompt">$</span> # Collector logs show the trace with resource attributes
<span class="prompt">$</span> docker logs otel-collector --tail 5
<span class="comment">trace_id=7f3e1a  service.name=checkout  deployment.environment=prod</span>
<span class="comment">  span=process_order  duration=127ms  baggage.tenant_id=acme</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">vendor-locked agent</span>
code rewrite per migration
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">OTel API + auto-instrument</span>
2-line bootstrap, zero code changes
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">any backend, same code</span>
Jaeger / Tempo / Datadog — swap exporters only
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Shopify**, the platform team adopted OTel in 2022 to migrate off a proprietary APM. Using auto-instrumentation, they instrumented 1,400 Ruby services in a single week without touching application code — just a gem add and env vars. They later switched backends from the proprietary APM to Grafana Tempo by changing only the collector's exporter config, saving an estimated $4M/year.
</div>

</div>

---

## 9. OTel Collector — receivers / processors / exporters

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** Apps shouldn't talk directly to four telemetry backends — they shouldn't know Prometheus exists, or that you just switched from Jaeger to Tempo. The Collector is the universal middleman: apps send OTLP to one place, the Collector translates, filters, samples, redacts, batches, and fans out. It's the `envoy` of telemetry — decouple producers from consumers, change backends without touching services.

<span class="stage thinking">Thinking</span>

**Mental model.** Receivers accept data → processors transform/filter → exporters send to backends. Every signal (metrics, logs, traces) flows through its own pipeline.

```mermaid
flowchart LR
  APP1[App OTLP] --> R1["Receiver<br/>otlp"]
  PROM[Prometheus scrape] --> R2["Receiver<br/>prometheus"]
  HOST[Host metrics] --> R3["Receiver<br/>hostmetrics"]
  R1 --> PIPE["Processors<br/>batch → memory_limiter<br/>→ tail_sampling → redact"]
  R2 --> PIPE
  R3 --> PIPE
  PIPE --> E1["Exporter<br/>otlp → Tempo"]
  PIPE --> E2["Exporter<br/>prometheusremotewrite"]
  PIPE --> E3["Exporter<br/>loki"]
```

- **Receivers** = "how data enters." `otlp`, `prometheus`, `filelog`, `hostmetrics`, `kafka`, `jaeger` (for migrations).
- **Processors** = "what happens to data." `batch` (always), `memory_limiter` (always), `tail_sampling`, `attributes` (redact PII), `filter`.
- **Exporters** = "how data leaves." `otlp`, `prometheusremotewrite`, `loki`, `kafka`, `debug` (stdout for testing).
- **Pipelines** = named flows: `traces/primary`, `metrics/slow`, `logs/redacted` — independent, per-signal.
- **Two binaries exist:** `otelcol` (core) and `otelcol-contrib` (core + 90+ community components). Use contrib in prod.

<span class="stage execution">Execution</span>

**Run it yourself.** A pipeline that accepts OTLP, redacts PII, samples tails, exports to Tempo + Prometheus.

```yaml
# /etc/otel/config.yaml
receivers:
  otlp:
    protocols: { grpc: {}, http: {} }
  hostmetrics:
    collection_interval: 30s
    scrapers: { cpu: {}, memory: {}, disk: {}, filesystem: {} }

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
  batch:
    send_batch_size: 1024
    timeout: 5s
  attributes/redact:
    actions:
      - key: http.request.header.authorization
        action: delete
      - key: user.email
        action: hash
  tail_sampling:
    decision_wait: 10s
    policies:
      - { name: errors, type: status_code, status_code: { status_codes: [ERROR] } }
      - { name: slow,   type: latency,     latency: { threshold_ms: 500 } }
      - { name: rest,   type: probabilistic, probabilistic: { sampling_percentage: 1 } }

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls: { insecure: true }
  prometheusremotewrite:
    endpoint: http://mimir:9009/api/v1/push
  debug: { verbosity: basic }

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, attributes/redact, tail_sampling, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp, hostmetrics]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
```

```bash
# Validate config before reload
otelcol-contrib validate --config /etc/otel/config.yaml

# Run + expose zpages for live pipeline debugging
otelcol-contrib --config /etc/otel/config.yaml
curl -s localhost:55679/debug/tracez | head
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> otelcol-contrib validate --config /etc/otel/config.yaml
<span class="comment">Configuration is valid</span>

<span class="prompt">$</span> otelcol-contrib --config /etc/otel/config.yaml
<span class="comment">info  Everything is ready. Begin running and processing data.</span>
<span class="comment">info  Pipeline: traces/primary  receivers=[otlp] processors=[...] exporters=[otlp/tempo]</span>
<span class="comment">info  Pipeline: metrics/primary receivers=[otlp,hostmetrics] exporters=[prometheusremotewrite]</span>

<span class="prompt">$</span> # Inspect live pipeline state
<span class="prompt">$</span> curl -s localhost:55679/debug/tracez
<span class="comment">processor/tail_sampling:  decisions=4211  sampled=127 (3%)</span>
<span class="comment">processor/batch:          batches_sent=842  dropped=0</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">direct app→backend wire</span>
4 SDKs, 4 endpoints, 4 auths
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">Collector in the middle</span>
OTLP in, PII redacted, tail sampled
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">swap backend by config</span>
apps untouched, PII never leaves cluster
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At eBay**, the platform team runs a fleet of 200+ OTel Collectors as the telemetry backbone for 4,000 services. During their 2023 migration from Splunk to Grafana Cloud, they changed one line — the exporter config — and shifted 8 TB/day of telemetry in a zero-downtime rollout. Previously, the same migration was scoped at 18 months of SDK rewrites. OTel Collector cut it to two weeks.
</div>

</div>

---

## 10. SLO / SLI / error budget — SRE math

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** "Is the site up?" is a useless question. A 500-error rate of 0.01% means the site is up. 0.5% means the site is failing for millions of users. SLOs convert vague availability goals into a **single number with a decimal point** and a **budget you can spend**. The budget lets product and engineering have an actual conversation: "we've burned 80% of this quarter's budget — no new deploys until Tuesday."

<span class="stage thinking">Thinking</span>

**Mental model.** SLI = the measurement. SLO = the target. Error budget = 1 − SLO over the window.

```mermaid
flowchart LR
  SLI["SLI<br/>successful_requests / total<br/>measured every 1m"] --> AGG["Aggregate<br/>30-day window"]
  AGG --> CUR[Current: 99.93%]
  TGT["SLO<br/>target: 99.9%"] --> BUDGET["Error budget<br/>0.1% = 43.2 min/month"]
  CUR --> REMAIN["Remaining budget<br/>= 30.2 min unused"]
  BUDGET --> POLICY{Budget < 0 ?}
  REMAIN --> POLICY
  POLICY -->|yes| FREEZE[Freeze releases]
  POLICY -->|no| SHIP[Ship features]
```

- **SLI** (indicator) = measurable ratio, usually `good_events / total_events`. Must be user-facing (HTTP 2xx, not CPU%).
- **SLO** (objective) = the target, e.g. `99.9%` — the "three nines" gives 43.2 min downtime/month.
- **Error budget** = `1 − SLO` = allowed failure. 99.9% SLO → 0.1% budget → ~43 min/month.
- **Burn rate** = how fast you're consuming the budget. 1x = exactly on budget, 14.4x = budget gone in 2 days.
- **Golden rule:** 100% is never a target. 100% means you can never ship, never maintain, never fail-in-staging.

<span class="stage execution">Execution</span>

**Run it yourself.** Calculate your SLO from live data.

```bash
# 1. Define SLI in PromQL — success ratio over 30d
SLI='sum(rate(http_requests_total{job="checkout",status!~"5.."}[30d])) / sum(rate(http_requests_total{job="checkout"}[30d]))'

# 2. Query it
curl -sG localhost:9090/api/v1/query --data-urlencode "query=$SLI" | jq '.data.result[0].value[1]'
# e.g. "0.99937" — we're at 99.937%, SLO target is 99.9%, we have budget.

# 3. Compute remaining budget
# budget_remaining = (current_sli - slo_target) / (1 - slo_target)
python3 -c "print(f'{(0.99937 - 0.999) / (1 - 0.999) * 100:.1f}% budget remaining')"

# 4. Burn rate over 1h (to detect fast burn)
BURN='sum(rate(http_requests_total{job="checkout",status=~"5.."}[1h])) / sum(rate(http_requests_total{job="checkout"}[1h])) / 0.001'
curl -sG localhost:9090/api/v1/query --data-urlencode "query=$BURN" | jq '.data.result[0].value[1]'
# 1.0 = on budget. 14.4 = panic.
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> promtool query instant localhost:9090 \
    'sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))'
<span class="comment">{} => 0.99937    # 99.937% — above 99.9% SLO</span>

<span class="prompt">$</span> python3 -c "print(f'{(0.99937-0.999)/(1-0.999)*100:.1f}% remaining')"
<span class="comment">37.0% remaining    # safe to keep shipping</span>

<span class="prompt">$</span> # Hour later: deploy regression
<span class="prompt">$</span> promtool query instant localhost:9090 "$BURN"
<span class="comment">{} => 22.3      # 22x burn — budget gone in 1.3 days at this rate</span>
<span class="comment">              # policy says: freeze, page, rollback</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">vague "reliable" goal</span>
PM argues with SRE every sprint
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">SLO + budget formalised</span>
99.9% target, 43 min/month budget
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">data-driven release policy</span>
budget spent → freeze, reliability work
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Google**, the SRE book defines the error budget policy that Gmail, Search, and Ads all follow: "If the service is within its error budget, release teams may take reasonable risks. If the service is out of its error budget, release teams are restricted from pushing changes." This single policy, documented across the industry since 2016, is cited by Netflix, Spotify, Shopify, and Etsy as the foundation of their release velocity vs. reliability trade-off.
</div>

</div>

---

## 11. Alertmanager — inhibition, grouping, silence, routing tree

<div class="concept" markdown>

<span class="stage reason">Reason</span>

**Why this exists.** A node dies. Prometheus fires 400 alerts (one per pod that just went NotReady). Your on-call phone explodes. Alertmanager is the nervous system: it **groups** related alerts into one notification, **inhibits** downstream alerts when a root cause fires, lets you **silence** during maintenance, and **routes** by severity/team. Without it, alert fatigue kills your on-call within a month.

<span class="stage thinking">Thinking</span>

**Mental model.** Prometheus sends alerts to Alertmanager → router walks a tree → matches label rules → sends to receivers (Slack/PagerDuty/email).

```mermaid
flowchart TB
  PROM[Prometheus] -->|alerts with labels| AM[Alertmanager]
  AM --> GROUP["Grouping<br/>by cluster+alertname"]
  GROUP --> INHIBIT["Inhibition<br/>NodeDown silences PodDown"]
  INHIBIT --> SILENCE["Silence check<br/>matcher: env=stg&maint=true"]
  SILENCE --> ROUTE{Router tree}
  ROUTE -->|team=payments,sev=page| PD[PagerDuty]
  ROUTE -->|sev=ticket| JIRA[Jira]
  ROUTE -->|default| SLACK[#alerts]
```

- **Grouping** = collapse N alerts with matching `group_by` labels into one notification — `group_by: [cluster, alertname]`.
- **Inhibition** = when alert A fires, suppress alert B. Classic: `NodeDown` inhibits `PodCrashLoop` (because all pods on the node will crash).
- **Silence** = explicit "shut up" with matchers and a time window. Used during maintenance. Expires automatically.
- **Routing tree** = ordered match rules. First match wins for `continue: false`; otherwise falls through to siblings.
- **Receivers** = where notifications go — Slack webhook, PagerDuty service key, email, custom webhook.

<span class="stage execution">Execution</span>

**Run it yourself.** A real-world Alertmanager config with grouping, inhibition, routing.

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url_file: /etc/alertmanager/slack_url

route:
  group_by: [cluster, alertname]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: default-slack
  routes:
    - matchers: [severity="page", team="payments"]
      receiver: pd-payments
      continue: false
    - matchers: [severity="page"]
      receiver: pd-default
    - matchers: [severity="ticket"]
      receiver: jira

inhibit_rules:
  - source_matchers: [alertname="NodeDown"]
    target_matchers: [alertname=~"PodCrashLoop|KubePodNotReady"]
    equal: [cluster, node]

receivers:
  - name: default-slack
    slack_configs:
      - channel: '#alerts'
        title: '{{ .CommonLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
  - name: pd-payments
    pagerduty_configs:
      - service_key_file: /etc/alertmanager/pd_payments
  - name: pd-default
    pagerduty_configs:
      - service_key_file: /etc/alertmanager/pd_default
  - name: jira
    webhook_configs:
      - url: http://jira-bridge:8080/alert
```

```bash
# Validate config
amtool check-config alertmanager.yml

# Dry-run a route to see which receiver wins
amtool config routes test \
  --config.file=alertmanager.yml \
  severity=page team=payments alertname=CheckoutDown
# => pd-payments

# Create a silence for a maintenance window
amtool --alertmanager.url=http://localhost:9093 silence add \
  alertname=DiskFull env=stg \
  --duration=2h --comment="disk expansion maintenance"

# List active silences
amtool silence query
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> amtool check-config alertmanager.yml
<span class="comment">Checking 'alertmanager.yml'  SUCCESS</span>
<span class="comment">Found:</span>
<span class="comment"> - global config</span>
<span class="comment"> - route with 3 child routes</span>
<span class="comment"> - 1 inhibit rule</span>
<span class="comment"> - 4 receivers</span>

<span class="prompt">$</span> amtool config routes test severity=page team=payments alertname=CheckoutDown
<span class="comment">default-slack -> pd-payments</span>

<span class="prompt">$</span> # Node dies — would normally fire 200 PodCrashLoop alerts
<span class="prompt">$</span> # With inhibition: only 1 notification sent
<span class="prompt">$</span> amtool alert query | wc -l
<span class="comment">1    # NodeDown (all PodCrashLoop suppressed)</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">400 pages at 03:00</span>
on-call quits within a month
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">grouping + inhibition</span>
N alerts → 1 notification
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">one page, right team</span>
PD routes payments→payments on-call
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At GitLab**, the infrastructure team publicly documented their Alertmanager routing tree as part of their "Everything is a YAML" philosophy. The tree has 38 branches routing to 14 teams, and the inhibition rules alone prevent ~2,000 redundant pages per month during node failures. Their public SRE handbook specifies: "If a single incident generates more than 3 pages, we treat it as a grouping bug and fix the Alertmanager config."
</div>

</div>

---

## 12. Cardinality discipline — why one bad label kills your cluster

<div class="concept" markdown>

<span class="stage reason">Reason</span>

!!! prod-danger "The Cardinality Explosion Anti-Pattern"
    **Never use high-cardinality values (user IDs, trace IDs, URLs) as Prometheus label values.**
    Each unique label combination creates a new time series. 1M users × 1 metric = 1M series → OOM crash. Use histograms for per-request data and keep label cardinality under 10,000 per metric.

**Why this exists.** Every unique combination of label values creates a new **time series**. `http_requests_total{method="GET", status="200", path="/health"}` = 1 series. Add a `user_id` label and each of your 50M users creates a series. Prometheus RAM explodes, scrape times hit 30s+, queries OOM. One intern adds `request_id` to a metric at 14:00, the cluster is dead by 14:05. This isn't a bug, it's physics — TSDBs index by label set.

<span class="stage thinking">Thinking</span>

**Mental model.** Every unique label-set = 1 series. Series × bytes-per-sample = RAM.

```mermaid
flowchart LR
  M[http_requests_total] --> DIM1[method: GET/POST/PUT → 3]
  M --> DIM2[status: 200/400/500 → 3]
  M --> DIM3[path: /api/users, /health → 2]
  DIM1 --> PROD[3 × 3 × 2 = 18 series ✓]
  DIM2 --> PROD
  DIM3 --> PROD
  M --> BAD[+ user_id: 50M unique]
  BAD --> BOOM["3×3×2×50M = 900M series ✗<br/>~3.5 TB RAM"]
```

- **Cardinality = the product of unique values per label.** Not the sum.
- **High-cardinality labels:** user_id, request_id, trace_id, email, URL with IDs, full error message, UUID, timestamp-string.
- **Low-cardinality labels (safe):** HTTP method, status code (bucketed), region, environment, service name.
- **Rule of thumb:** a single metric should not exceed ~10k series. A Prometheus should not exceed ~10M total.
- **Cure, not prevention:** when you find a bad label, use `metric_relabel_configs` to drop it at scrape time.

<span class="stage execution">Execution</span>

**Run it yourself.** Audit and kill high-cardinality offenders.

```bash
# 1. Top 20 highest-cardinality metrics
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=topk(20, count by (__name__) ({__name__=~".+"}))' | jq '.data.result[] | {metric: .metric.__name__, series: .value[1]}'

# 2. Per-label cardinality inside a bad metric
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=count(count by (path) (http_requests_total))' | jq .
# If path has 50k values — you have URLs with IDs in them.

# 3. Overall series count & limit
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.headStats'

# 4. Kill a bad label at scrape time (Prometheus config)
cat >> /etc/prometheus/prometheus.yml <<'EOF'
scrape_configs:
  - job_name: checkout
    metric_relabel_configs:
      - source_labels: [__name__, user_id]
        regex: 'http_requests_total;.+'
        action: labeldrop           # drops user_id from this metric
      - source_labels: [path]
        regex: '/api/users/[0-9]+/orders'
        target_label: path
        replacement: '/api/users/:id/orders'   # collapse IDs
EOF
curl -X POST localhost:9090/-/reload
```

<span class="stage simulation">Simulation — what you'll see</span>

<pre class="sim"><code><span class="prompt">$</span> promtool query instant localhost:9090 \
    'topk(5, count by (__name__) ({__name__=~".+"}))'
<span class="comment">{ __name__="http_requests_total" }  => 4,210,000   ✗ cardinality bomb</span>
<span class="comment">{ __name__="go_gc_duration"       }  =>    35</span>
<span class="comment">{ __name__="node_cpu_seconds"     }  =>    96</span>

<span class="prompt">$</span> # Find which label caused it
<span class="prompt">$</span> promtool query instant localhost:9090 \
    'count(count by (path) (http_requests_total))'
<span class="comment">{} => 58,432    # 58k unique paths = URLs with IDs</span>

<span class="prompt">$</span> # After metric_relabel_configs collapse
<span class="prompt">$</span> curl -X POST localhost:9090/-/reload
<span class="prompt">$</span> promtool query instant localhost:9090 \
    'count(count by (path) (http_requests_total))'
<span class="comment">{} => 42        # collapsed to route patterns ✓</span>

<span class="prompt">$</span> free -h
<span class="comment"># Prometheus RAM: 18 GB -> 1.4 GB</span>
</code></pre>

<span class="stage output">Output — state change</span>

<div class="flow" markdown>

<div class="state before" markdown>
##### Before
<span class="diff-del">4.2M series on one metric</span>
Prom OOMs every 6 hours
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### During
<span class="diff-mod">audit + relabel_configs</span>
drop user_id, collapse paths
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### After
<span class="diff-add">42 series, 1.4 GB RAM</span>
queries < 100ms, no more OOM
</div>

</div>

<span class="stage usecase">Real-world use case</span>

<div class="usecase-card" markdown>
**At Grafana Labs**, the Mimir team tells the "accidental intern" story at every KubeCon: an intern added `trace_id` as a Prometheus label on a single counter. Within 4 minutes, the production Prometheus went from 3M to 280M series, OOM'd, and the entire observability stack went dark during a Black Friday-adjacent incident. The fix — a one-line `labeldrop` — took 30 seconds. The policy change — automated cardinality alerting via `prometheus_tsdb_head_series > 10000000` — became a permanent feature, now shipped with `kube-prometheus-stack` by default.
</div>

</div>

---

## Lab index — hands-on deep dives

The subfolders below drill into each topic with runnable code. Treat them as the "hands on keyboard" companion to the concepts above.

| # | Topic | Folder |
|---|-------|--------|
| 01 | Three pillars: signals + SLO/SLI vocabulary | [01-three-pillars](./01-three-pillars/) |
| 02 | Prometheus: pull model, exporters, PromQL | [02-prometheus](./02-prometheus/) |
| 03 | Grafana: dashboards, panels, provisioning | [03-grafana](./03-grafana/) |
| 04 | Loki: log aggregation, LogQL | [04-loki](./04-loki/) |
| 05 | Tempo: distributed tracing | [05-tempo-tracing](./05-tempo-tracing/) |
| 06 | OpenTelemetry: SDK, collector, OTLP | [06-opentelemetry](./06-opentelemetry/) |
| 07 | kube-prometheus-stack: full Helm bundle | [07-kube-prometheus-stack](./07-kube-prometheus-stack/) |
| 08 | Alerting: Alertmanager routing, silences | [08-alerting](./08-alerting/) |
| 09 | SLO engineering: budgets, burn rates | [09-slo-engineering](./09-slo-engineering/) |
| 10 | Cost & cardinality: label hygiene, Thanos/Mimir | [10-cost-and-cardinality](./10-cost-and-cardinality/) |
| &nbsp; | Commands quick-pick | [commands.md](./commands.md) |
| &nbsp; | One-page cheatsheet | [cheatsheet.md](./cheatsheet.md) |

---

## Suggested learning path

1. **Read the 12 concepts above** end-to-end — once you can state each in one sentence, you have the vocabulary.
2. **Stand up Prometheus + Grafana** from the `02` and `03` labs. Verify `up == 1`, render a p99 panel.
3. **Layer logs (`04-loki`) and traces (`05-tempo-tracing`).** Correlate one request across all three.
4. **Replace hand-rolled instrumentation with OTel (`06`).** Auto-instrument, then migrate custom spans.
5. **Productionize via `07-kube-prometheus-stack`.** Reload rules, wire Alertmanager (`08`).
6. **Define the first SLO (`09`).** Compute error budget, write the burn-rate alert.
7. **Return to `10-cost-and-cardinality`** the first month the bill hurts — it will.
