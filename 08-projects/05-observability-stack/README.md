# Project 05 · Observability Stack

<span class="level advanced">advanced</span>
<span class="tag">stack: python · opentelemetry · prometheus · loki · tempo · grafana · k8s · helm</span>

<p class="tagline"><em>One request ID links its metric spike, its log line, and its trace — three pillars, one truth.</em></p>

<div class="metrics" markdown>
<span class="m"><b>Time</b> 6 h</span>
<span class="m"><b>Cost</b> $0 (local kind)</span>
<span class="m"><b>p95 target</b> &lt; 500 ms</span>
<span class="m"><b>SLO target</b> 99.5 % availability</span>
</div>

---

## Roadmap

<div class="roadmap" markdown>
<div class="stop" data-step="1" markdown>
#### Stage 1 — Instrument with the OTel SDK
Wire traces, metrics, and logs into the FastAPI service without changing business logic.
</div>
<div class="stop" data-step="2" markdown>
#### Stage 2 — OTel Collector pipeline
The Collector receives all three signal types over OTLP and fans them out to three separate backends.
</div>
<div class="stop" data-step="3" markdown>
#### Stage 3 — Prometheus scrape + PromQL
The ServiceMonitor tells Prometheus where to scrape; PromQL answers rate, error, and saturation questions.
</div>
<div class="stop" data-step="4" markdown>
#### Stage 4 — Loki logs + LogQL
Structured log lines land in Loki with a `trace_id` label. LogQL filters by severity and service.
</div>
<div class="stop" data-step="5" markdown>
#### Stage 5 — Tempo traces + TraceQL
Every span arrives in Tempo with a `trace_id` that matches the metric exemplar and the log field.
</div>
<div class="stop" data-step="6" markdown>
#### Stage 6 — SLO burn-rate alerts
Multi-window burn-rate panels catch both fast spikes (5 % budget in 1 h) and slow leaks (2 % in 6 h).
</div>
</div>

---

## Stage 1 — Instrument with the OTel SDK

### Why OpenTelemetry?

Before OTel every vendor had its own agent. A Datadog-instrumented service couldn't talk to Jaeger. OTel defines a single wire format (OTLP) and a single SDK — you instrument once and choose your backends later. The Collector sits in the middle and routes signals without the app knowing or caring.

### What the SDK does in `app/main.py`

```python
# One Resource describes the service to all three signal providers
resource = Resource.create({
    ResourceAttributes.SERVICE_NAME: "obs-demo",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
})

# Traces
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True))
)
trace.set_tracer_provider(tracer_provider)

# Metrics (SDK → Collector → Prometheus remote-write)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Logs (patches Python stdlib logging — zero app-code change)
LoggingInstrumentor().instrument(set_logging_format=True)
```

The `FastAPIInstrumentor.instrument_app(app)` call adds automatic span creation for every HTTP request. The `LoggingInstrumentor` patches Python's `logging` module so that every `logger.info(...)` call automatically includes `trace_id` and `span_id` from the active span context.

### The four demo endpoints

| Endpoint | Behaviour | Drives |
|----------|-----------|--------|
| `/fast` | Returns in ~1 ms | Rate panel baseline |
| `/slow` | Sleeps 1.5 – 2.5 s | Duration / p95 latency panel |
| `/flaky` | Returns HTTP 500 ~30 % | Error rate panel + SLO burn |
| `/cpu` | Burns CPU for 200 ms | Saturation panel |

### Manual span annotation

```python
@app.get("/slow")
async def slow():
    with tracer.start_as_current_span("slow-handler") as span:
        delay = random.uniform(1.5, 2.5)
        span.set_attribute("demo.simulated_delay_s", round(delay, 3))
        with tracer.start_as_current_span("db-query"):   # child span
            logger.info("slow endpoint: simulating DB query")
            time.sleep(delay)
```

The nested `db-query` span appears as a child in Tempo, showing exactly where the latency lives.

---

## Stage 2 — OTel Collector pipeline

### Why a Collector?

The app sends one OTLP stream. The Collector splits it three ways:

```
App ──OTLP gRPC──► Collector ──► Tempo      (traces)
                            ──► Loki       (logs)
                            ──► Prometheus (metrics, with exemplars)
```

Without the Collector, the app would need three exporters and three sets of credentials.

### Processor chain

```yaml
# infra/otel-collector/config.yaml — key excerpt
processors:
  memory_limiter:         # backpressure: drops signals before OOM
    limit_mib: 256
  batch:                  # amortises network round-trips
    send_batch_size: 1024
    timeout: 5s
  resource:               # enriches every span/metric/log
    attributes:
      - key: k8s.cluster.name
        value: "obs-demo-cluster"
        action: insert
  transform/add_exemplars: # attach trace_id to metric datapoints
    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["trace_id"], trace_id.string) where trace_id != nil
```

The `transform/add_exemplars` processor is the bridge between Pillar 1 (metrics) and Pillar 3 (traces). It stamps each histogram data point with the `trace_id` of the request that produced it. Prometheus stores this as an [exemplar](https://prometheus.io/docs/prometheus/latest/feature_flags/#exemplars-storage) and Grafana renders it as a clickable diamond on the latency panel.

### Full pipeline

```
receivers:  otlp (gRPC 4317 + HTTP 4318)
processors: memory_limiter → resource → batch
exporters:
  traces  → otlp/tempo
  metrics → prometheusremotewrite (with exemplars)
  logs    → loki (label mapping: service.name → service_name)
  all     → debug (stdout sampling)
```

---

## Stage 3 — Prometheus scrape + PromQL

### Two metrics paths

The service exposes a `/metrics` endpoint for Prometheus pull-scraping (via ServiceMonitor) **and** pushes metrics to Prometheus via the OTel Collector remote-write. The dual path is intentional:

- **Pull scrape** survives Collector restarts — metrics never drop to zero.
- **Remote-write** carries exemplars — the pull scrape cannot carry exemplar data in Prometheus 2.x.

### ServiceMonitor

```yaml
# infra/k8s/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    release: kube-prom-stack   # must match kube-prom-stack's selector
spec:
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

The `release: kube-prom-stack` label tells the Prometheus Operator to include this ServiceMonitor in the Prometheus configuration. Without it the scrape target is silently ignored.

### Key PromQL queries

| Signal | Query |
|--------|-------|
| Request rate | `sum by (endpoint) (rate(demo_requests_total[5m]))` |
| Error rate | `sum by (endpoint) (rate(demo_requests_total{status=~"5.."}[5m]))` |
| p95 latency | `histogram_quantile(0.95, sum by (le)(rate(demo_request_duration_seconds_bucket[5m])))` |
| CPU saturation | `rate(container_cpu_usage_seconds_total{container="obs-demo"}[5m]) / kube_pod_container_resource_limits{resource="cpu"}` |
| SLO availability | `1 - (sum(rate(demo_requests_total{status=~"5.."}[30d])) / sum(rate(demo_requests_total[30d])))` |

---

## Stage 4 — Loki logs + LogQL

### Structured log format

The `LoggingInstrumentor` patches Python's `logging` formatter to emit:

```
2024-01-15 12:34:56,789 INFO [obs-demo] [trace_id=4bf92f3577b34da6 span_id=00f067aa0ba902b7] slow endpoint: simulating DB query
```

The OTel Collector's Loki exporter maps resource attributes to Loki labels:

```yaml
labels:
  resource:
    service.name: "service_name"   # becomes {service_name="obs-demo"}
```

### LogQL queries

| Query | Purpose |
|-------|---------|
| `{service_name="obs-demo"}` | All app logs |
| `{service_name="obs-demo"} \|= "ERROR"` | Errors only |
| `{service_name="obs-demo"} \| json \| trace_id="4bf92f35..."` | Single trace |
| `sum(rate({service_name="obs-demo"} \|= "error" [5m]))` | Error log rate |

### Derived field — the log → trace link

The Grafana datasource provisioning (`grafana/provisioning/datasources.yaml`) configures a **derived field** on the Loki datasource:

```yaml
derivedFields:
  - matcherRegex: '"trace_id":"([a-f0-9]{32})"'
    name: TraceID
    datasourceUid: tempo
    url: "${__value.raw}"
```

This regex extracts the `trace_id` from every log line and renders it as a hyperlink. Click the link → Tempo opens the matching trace. No copy-paste required.

---

## Stage 5 — Tempo traces + TraceQL

### What Tempo stores

Each trace is a tree of spans. For a `/slow` request the tree looks like:

```
GET /slow  [2.1s]
  └─ slow-handler  [2.1s]
       ├─ db-query  [2.0s]    ← manual child span
       └─ (auto-instrumented HTTP framework spans)
```

### TraceQL queries

```
# All slow spans > 1.5s
{ .http.target = "/slow" && duration > 1.5s }

# All error spans
{ status = error }

# Spans from a specific service
{ resource.service.name = "obs-demo" }

# Combine: slow errors from obs-demo
{ resource.service.name = "obs-demo" && status = error && duration > 500ms }
```

### Metrics-generator

Tempo's built-in metrics generator computes RED (Rate, Errors, Duration) metrics from trace data and remote-writes them to Prometheus. This creates service graph metrics without any additional instrumentation:

```yaml
metrics_generator:
  enabled: true
  storage:
    remote_write:
      - url: http://prometheus-operated:9090/api/v1/write
        send_exemplars: true
```

---

## Stage 6 — SLO burn-rate alerts

### Google SRE model

The SLO burn-rate model (from the Google SRE workbook) answers: *"How fast are we consuming our error budget?"*

A 99.5 % availability SLO allows 0.5 % errors over 30 days = **216 minutes** of downtime budget.

A burn rate of 1x means the budget is being consumed exactly as fast as it accrues. A burn rate of 14.4x means the budget will be exhausted in 1 / 14.4 * 720h ≈ 50 hours.

### Multi-window alerting

| Window | Threshold | Meaning | Action |
|--------|-----------|---------|--------|
| 1h + 5m | burn > 14.4x | 5 % budget consumed in 1h | Page on-call immediately |
| 6h + 30m | burn > 6x | 5 % budget consumed in 6h | Page on-call |
| 1h + 5m | burn > 3x | 10 % budget consumed in 3d | Create ticket |

The dual-window check (e.g., both 1h and 5m must exceed the threshold) prevents alert noise from short spikes. If only the 5m window is elevated, it's likely transient.

### PromQL burn-rate formula

```promql
# Instantaneous burn rate (1h window)
(
  sum(rate(demo_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(demo_requests_total[1h]))
) / (1 - 0.995)
```

The division by `(1 - 0.995)` normalises the error rate against the SLO target, so the result is "multiples of the allowed error rate."

---

## Architecture diagram

See [`architecture.md`](./architecture.md) for the full layered flowchart and sequence diagram.

---

## Run it

```bash
make up          # kind cluster + full stack (~8 min)
make demo-trace  # fire one request, capture trace_id, verify three-pillar link
make demo-slow   # 20 slow requests → drives p95 latency panel
make demo-error  # 100 flaky requests → drives error rate + SLO burn
make perf        # k6 smoke test (3 min, all endpoints)
make down        # destroy cluster
```

## Simulation — expected output

<pre class="sim"><code><span class="prompt">$</span> make up
<span class="comment"># ── Creating kind cluster: obs-demo-cluster</span>
<span class="comment"># ── Building obs-demo:1.0.0</span>
<span class="comment"># ── Installing kube-prometheus-stack ... done</span>
<span class="comment"># ── Installing Loki ... done</span>
<span class="comment"># ── Installing Tempo ... done</span>
<span class="comment"># ── Waiting for all pods to be Running ... ok</span>
<span class="comment">#</span>
<span class="comment">#   Stack is up!</span>
<span class="comment">#   Grafana  → http://localhost:3000  (admin / obs-demo-secret)</span>
<span class="comment">#   App      → http://localhost:8000</span>

<span class="prompt">$</span> make demo-trace
<span class="comment"># {"endpoint": "slow", "delay_s": 1.87}</span>
<span class="comment"># Captured trace_id: 4bf92f3577b34da6a3ce929d0e0e4736</span>
<span class="comment">#</span>
<span class="comment">#   1. Open Grafana → Four Golden Signals</span>
<span class="comment">#   2. Click a diamond exemplar on the latency panel</span>
<span class="comment">#   3. Click 'View in Tempo' → span: slow-handler  duration: 1.87s</span>
<span class="comment">#   4. Click 'Logs for this span' → Loki log line with same trace_id</span>

<span class="prompt">$</span> make perf
<span class="comment"># k6 running 3m — 100 VUs</span>
<span class="comment"># ✔ /fast  p95 = 4ms   (target &lt;50ms)</span>
<span class="comment"># ✔ /slow  p95 = 2.4s  (target &lt;3s)</span>
<span class="comment"># ✔ /cpu   p95 = 220ms (target &lt;500ms)</span>
<span class="comment"># ✔ error rate 28.4%   (target &lt;35%, flaky by design)</span>
</code></pre>

## Output — three-pillar correlation

<div class="flow" markdown>

<div class="state before" markdown>
##### Request fires
Trace ID `4bf92f35...` assigned by OTel SDK
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### All three pillars receive it
<span class="diff-mod">Prometheus: exemplar{trace_id="4bf92f35..."}</span>
<span class="diff-mod">Loki: {trace_id="4bf92f35..."}</span>
<span class="diff-mod">Tempo: traceID=4bf92f35...</span>
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### Grafana links all three
<span class="diff-add">Click exemplar → span → log</span>
Zero manual search
</div>

</div>

## Real-world context

<div class="usecase-card" markdown>
**At Uber**, Jaeger (the origin of Tempo's design) was built after engineers spent hours per incident manually correlating Kibana log searches with ad-hoc metric graphs. The exemplar-based correlation model — where a single ID links all three signals — reduced the median time-to-identification from 47 minutes to 8 minutes for their payment reliability team. This project implements the same model on Grafana Labs' open-source stack.
</div>

---

## QA engineer's test plan

See [`tests/qa-plan.md`](./tests/qa-plan.md). The critical test is Phase 3 — the three-pillar correlation drill.

| Phase | Test | Tool | Pass criteria |
|-------|------|------|---------------|
| 1 | App starts, /healthz 200, /metrics scraped | curl | all pass |
| 2 | Collector pipelines: traces → Tempo, logs → Loki, metrics → Prom | curl | all non-empty |
| 3 | Same trace_id in Prometheus exemplar + Loki log + Tempo span | curl + Grafana | 3/3 match |
| 4 | k6 smoke — p95 and error rate thresholds | k6 | p95 < 500ms, errors < 35% |
| 5 | SLO burn-rate panel renders, gauge non-NaN | Grafana | visual pass |
| 6 | Pod kill during load — < 5% extra errors | kubectl + k6 | error delta < 5% |

## Performance baseline

k6 script at `tests/k6/smoke.js`. Run with `make perf`. Expected:

- `/fast` p95: < 50 ms
- `/slow` p95: < 3 s
- `/cpu` p95: < 500 ms
- `/flaky` error rate: ~30% (intentional — drives the SLO panels)

## Files in this project

| File | Purpose |
|------|---------|
| `app/main.py` | FastAPI service with full OTel SDK instrumentation |
| `app/requirements.txt` | Pinned OTel + FastAPI deps |
| `app/Dockerfile` | Multi-stage, non-root, health check |
| `infra/otel-collector/config.yaml` | Full Collector pipeline config |
| `infra/k8s/deployment.yaml` | Deployment + ServiceAccount |
| `infra/k8s/service.yaml` | ClusterIP service |
| `infra/k8s/servicemonitor.yaml` | Prometheus Operator scrape target |
| `infra/k8s/configmap-otel.yaml` | Collector ConfigMap + Deployment |
| `infra/helm-values/kube-prom-stack.yaml` | Prometheus + Grafana + Alertmanager |
| `infra/helm-values/loki.yaml` | Loki single-binary, local storage |
| `infra/helm-values/tempo.yaml` | Tempo single-binary, metrics generator |
| `grafana/dashboards/golden-signals.json` | Four Golden Signals dashboard |
| `grafana/dashboards/slo-burn-rate.json` | SLO burn-rate dashboard |
| `grafana/provisioning/datasources.yaml` | All three datasources pre-wired |
| `Makefile` | up / demo-* / perf / down |
| `tests/qa-plan.md` | Six-phase QA plan with correlation drill |
| `tests/k6/smoke.js` | k6 load test — all four endpoints |

---

## Further reading

- Architecture deep-dive: [`architecture.md`](./architecture.md)
- QA plan: [`tests/qa-plan.md`](./tests/qa-plan.md)
- [OpenTelemetry Python SDK](https://opentelemetry-python.readthedocs.io/)
- [Google SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Grafana Exemplars](https://grafana.com/docs/grafana/latest/fundamentals/exemplars/)
- [Tempo TraceQL](https://grafana.com/docs/tempo/latest/traceql/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/query/)
