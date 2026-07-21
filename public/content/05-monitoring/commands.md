# Monitoring · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."
> Pane numbers map to how you should lay out your tmux during an incident.

## Pane 1 — triage (is it really broken?)

```bash
# Are all scrape targets up?
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up") | {job:.labels.job, err:.lastError}'

# Global error ratio (is this a real incident?)
promtool query instant localhost:9090 \
  'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'

# p99 latency right now, per service
promtool query instant localhost:9090 \
  'histogram_quantile(0.99, sum by (le,service) (rate(http_request_duration_seconds_bucket[5m])))'

# Active alerts (what's firing?)
curl -s localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name:.labels.alertname, sev:.labels.severity, state}'

# SLO burn rate (is budget on fire?)
promtool query instant localhost:9090 \
  'sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h])) / 0.001'
```

## Pane 2 — diagnose (why is it broken?)

```bash
# Error logs for the hot service, last 15m
logcli --addr=http://localhost:3100 query \
  '{app="checkout", level="error"}' --since=15m --limit=50

# Extract JSON field — find errors for a specific tenant
logcli query '{app="checkout"} | json | tenant_id="acme" | status_code >= 500' --since=15m

# Find slow traces
curl -sG localhost:3200/api/search \
  --data-urlencode 'q={ resource.service.name="checkout" && duration > 500ms }' | jq '.traces'

# Fetch a specific trace tree
curl -s "localhost:3200/api/traces/$TRACE_ID" | \
  jq '.batches[].scopeSpans[].spans[] | {name,durationMs:((.endTimeUnixNano|tonumber)-(.startTimeUnixNano|tonumber))/1e6}' | sort -k3 -n

# Pod restart rate (infra check)
promtool query instant localhost:9090 \
  'sum by (namespace,pod) (rate(kube_pod_container_status_restarts_total[15m]))'
```

## Pane 3 — contain (stop the bleeding)

```bash
# Silence noisy alert during a known maintenance
amtool --alertmanager.url=http://localhost:9093 silence add \
  alertname=DiskFull env=prod \
  --duration=2h --comment="disk expansion — INC-4821"

# List active silences
amtool silence query

# Expire a silence early
amtool silence expire <silence-id>

# Reload Prometheus config (after editing rules)
curl -X POST localhost:9090/-/reload

# Reload Alertmanager config
curl -X POST localhost:9093/-/reload
```

## Pane 4 — verify (is it fixed?)

```bash
# Watch error rate trend (refresh every 2s)
watch -n2 'promtool query instant localhost:9090 \
  "sum(rate(http_requests_total{status=~\"5..\"}[1m]))"'

# Confirm alert resolved
curl -s localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname=="SLOErrorBudgetFastBurn")'

# Is the fix deploy visible as an annotation?
promtool query instant localhost:9090 \
  'changes(process_start_time_seconds{job="checkout"}[5m])'
```

---

## PromQL · the 10 queries that matter

```promql
# 1. Request rate (RED: R)
sum by (service) (rate(http_requests_total[5m]))

# 2. Error rate (RED: E)
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))

# 3. Error ratio
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))

# 4. p99 latency (RED: D)
histogram_quantile(0.99,
  sum by (le,service) (rate(http_request_duration_seconds_bucket[5m])))

# 5. CPU % per node (USE: U)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 6. Memory % per node
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 7. Disk saturation (USE: S)
rate(node_disk_io_time_seconds_total[5m])

# 8. Pod restart rate
sum by (namespace,pod) (rate(kube_pod_container_status_restarts_total[15m]))

# 9. Top 20 highest-cardinality metrics (audit!)
topk(20, count by (__name__) ({__name__=~".+"}))

# 10. Up-check — a dead target never pushes fake zeros
up == 0
```

---

## LogQL · the essentials

```logql
# Stream select + grep
{app="checkout", namespace="prod"} |= "error" !~ "healthcheck"

# Parse JSON and filter by field
{app="checkout"} | json | status_code >= 500

# Extract with regex
{app="nginx"} | regexp `(?P<status>\d{3}) (?P<duration>\d+)ms` | duration > 1000

# Metric from logs — error rate per pod
sum by (pod) (rate({app="checkout"} |= "error" [5m]))

# Top-k slowest pods by log volume
topk(5, sum by (pod) (rate({app="checkout"} [5m])))

# Audit: how many streams do I have?
count by (app) (count_over_time({__name__!=""} [5m]))
```

---

## TraceQL · search traces like SQL

```traceql
# All error traces in last hour
{ status = error }

# Slow checkout operations
{ resource.service.name = "checkout" && duration > 500ms }

# Requests from a specific tenant (baggage propagated)
{ span.baggage.tenant_id = "acme" && duration > 1s }

# Traces that touched both services
{ resource.service.name = "gateway" } && { resource.service.name = "payment" }

# Spans with a DB error inside
{ span.db.system = "postgresql" && status = error }
```

---

## OpenTelemetry · env var recipes

```bash
# Auto-instrumentation (Python / Node / JVM)
export OTEL_SERVICE_NAME=checkout
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=prod,service.version=1.4.2,k8s.cluster.name=us-east"
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1                # 10%
export OTEL_LOGS_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp

# Python
opentelemetry-instrument python app.py

# Node
node --require '@opentelemetry/auto-instrumentations-node/register' app.js

# JVM
java -javaagent:opentelemetry-javaagent.jar -jar app.jar
```

---

## Alertmanager · amtool reference

```bash
# Validate config
amtool check-config alertmanager.yml

# Test route resolution (dry-run)
amtool config routes test --config.file=alertmanager.yml \
  severity=page team=payments alertname=CheckoutDown

# Add silence with matchers
amtool --alertmanager.url=http://localhost:9093 silence add \
  alertname=HighCPU env=stg --duration=1h --comment="stress test"

# Regex matcher silence (careful!)
amtool silence add 'alertname=~"Pod.*"' namespace=stg --duration=30m

# List + expire
amtool silence query
amtool silence expire <id>

# Active alerts
amtool alert query

# Debug routing for an alert
amtool --alertmanager.url=http://localhost:9093 alert query --receiver=pd-payments
```

---

## Kubernetes · kube-prometheus-stack

```bash
# Install / upgrade
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f values.yaml

# Port-forward the three pillars in one shot
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090 &
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093 &

# Verify ServiceMonitor selector
kubectl -n monitoring get prometheus -o yaml | grep -A2 serviceMonitorSelector

# See the actual Prometheus config mounted inside the pod
kubectl -n monitoring exec prometheus-kps-0 -c prometheus -- cat /etc/prometheus/config_out/prometheus.env.yaml

# Show current Alertmanager config
kubectl -n monitoring exec alertmanager-kps-0 -c alertmanager -- amtool config show

# Reload Prometheus / Alertmanager without pod restart
kubectl -n monitoring port-forward pod/prometheus-kps-0 9090 &
curl -X POST localhost:9090/-/reload
```

---

## Cardinality · audit & defuse

```bash
# Worst offenders (top 20)
promtool query instant localhost:9090 \
  'topk(20, count by (__name__) ({__name__=~".+"}))'

# Per-label cardinality inside a suspect metric
promtool query instant localhost:9090 \
  'count(count by (path) (http_requests_total))'

# Series count trend — should be flat, not rising
promtool query instant localhost:9090 \
  'prometheus_tsdb_head_series'

# Relabel drop — kill a bad label at scrape time
# (add to scrape_configs):
# metric_relabel_configs:
#   - source_labels: [__name__]
#     regex: 'http_requests_total'
#     action: labeldrop
#     replacement: user_id

# Loki stream audit
logcli series '{}' --since=1h | wc -l
# > 100k = someone indexed a UUID
```

---

## SLO math · copy-paste

```bash
# Error budget remaining (%)
python3 -c "sli=0.99937; slo=0.999; print(f'{(sli-slo)/(1-slo)*100:.1f}% budget left')"

# Burn rate thresholds (from Google SRE book)
# alert if both windows exceed the threshold:
#   14.4x (1h + 5m)   -> 2% of 30d budget in 1h,  page
#    6.0x (6h + 30m)  -> 5% of 30d budget in 6h,  page
#    3.0x (1d + 2h)   -> 10% budget in 1d,       ticket
#    1.0x (3d + 6h)   -> 10% budget in 3d,       ticket

# Single-burn-rate alert (PromQL)
# job:http_errors:ratio5m > (14.4 * 0.001)
#   and
# job:http_errors:ratio1h > (14.4 * 0.001)
```

---

## Production image refs (pin in charts)

| Tool | Image |
|------|-------|
| Prometheus | `prom/prometheus:v2.54.1` |
| Alertmanager | `prom/alertmanager:v0.27.0` |
| node-exporter | `prom/node-exporter:v1.8.2` |
| Grafana | `grafana/grafana:11.2.0` |
| Loki | `grafana/loki:3.2.0` |
| Promtail | `grafana/promtail:3.2.0` |
| Tempo | `grafana/tempo:2.6.0` |
| OTel Collector | `otel/opentelemetry-collector-contrib:0.110.0` |
| kube-state-metrics | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0` |
| Mimir | `grafana/mimir:2.13.0` |
| Thanos | `thanosio/thanos:v0.36.1` |

---

## Decision tree · which signal do you need?

```text
"Is it broken?"           → Metrics  (Prometheus)
"Why is it broken?"       → Logs     (Loki)
"Where in the stack?"     → Traces   (Tempo / Jaeger)
"What changed?"           → Events   (Grafana annotations / k8s events)
"How bad is it?"          → SLO/burn (Recording rule + Alertmanager)
"Who should I page?"      → Routing  (Alertmanager tree)
```

---

## Anti-patterns (WILL bite you in prod)

| Don't | Because |
|-------|---------|
| Use `user_id` or `trace_id` as a Prometheus label | Cardinality explodes — cluster dies in minutes |
| Alert on CPU > 80% | Symptom not cause — wakes you up, fixes nothing |
| `for: 0s` on alerts | Flapping — you'll be paged 50x/hour |
| 100% SLO target | Impossible — leaves no room to deploy or experiment |
| Email-only paging | Nobody reads alert email at 03:00 |
| Hand-edit `prometheus.yml` on K8s | Use `ServiceMonitor` / `PrometheusRule` CRDs |
| Ship logs to Elastic without label discipline | Pay 10x more than Loki for the same grep |
| App pushes directly to Tempo + Prom + Loki | Use a Collector — decouple from backend |
| Single-window burn-rate alert | Either flaps or misses slow burns — always multi-window |
| `kubectl apply` straight to prod Prometheus | Version rules; roll via CI + `--dry-run` first |
