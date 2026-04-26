# Monitoring Cheatsheet

## Mental model
- **Metrics** = what is wrong  | **Logs** = why  | **Traces** = where
- **RED** = Rate, Errors, Duration (services)
- **USE** = Utilization, Saturation, Errors (resources)
- **Golden Signals** = Latency, Traffic, Errors, Saturation

## Prometheus essentials

```promql
# RPS
sum(rate(http_requests_total[5m]))

# Error ratio
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))

# p99 latency
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m])))

# CPU % per node
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory % per node
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Pod restart rate
sum by (namespace,pod) (rate(kube_pod_container_status_restarts_total[15m]))

# Top 20 noisy metrics (cardinality audit)
topk(20, count by (__name__) ({__name__=~".+"}))

# Up check
up == 0
```

## LogQL essentials

```logql
{namespace="prod", app="api"} |= "error"
{namespace="prod"} | json | status >= 500
sum by (level) (rate({app="api"} | json [5m]))
```

## TraceQL

```
{ resource.service.name = "checkout-svc" && duration > 500ms && status = error }
```

## Useful Helm

```bash
helm install kps prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
helm install loki grafana/loki -n monitoring -f loki-values.yaml
helm install tempo grafana/tempo -n monitoring -f tempo-values.yaml
helm install otel open-telemetry/opentelemetry-collector -n monitoring -f otel-values.yaml
```

## Useful kubectl

```bash
# Port-forward stack
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093

# Verify ServiceMonitor is selected
kubectl -n monitoring get prometheus -o yaml | grep -A2 serviceMonitorSelector

# Check Alertmanager config
kubectl -n monitoring exec -it alertmanager-kps-0 -c alertmanager -- amtool config show
```

## Image refs (pin in production)

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

## Anti-patterns to avoid

- IDs as labels (cardinality explosion)
- Alerts without `for:` (flapping)
- 100% SLO targets (impossible)
- Email-only critical alerts (no one reads)
- Alerting on causes (CPU high) instead of symptoms (user errors)
- Apps writing directly to backends (use a collector)
- Editing prometheus.yml by hand on k8s (use ServiceMonitor CRDs)

## Decision tree

```
Need to ask "is this broken?"   -> Metrics  (Prometheus)
Need to ask "what was the error?"-> Logs    (Loki)
Need to ask "where in the stack?"-> Traces  (Tempo)
Need to ask "what changed?"      -> Events  (annotations / k8s events)
```
