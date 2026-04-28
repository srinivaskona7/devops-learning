# Three Pillars — Commands

> Quick pickup reference. Pair with `README.md` for theory.

This folder is conceptual — these are the query patterns you reach for when you have to demonstrate the four signals on real telemetry. No deploy steps; the pillars live inside the other folders.

## Setup

Nothing to install here. You need a running Prometheus, Loki and Tempo to exercise these queries — see `02-prometheus`, `04-loki`, `05-tempo-tracing`.

```bash
# Sanity-check each backend is reachable
curl -s http://localhost:9090/-/ready    # Prometheus
curl -s http://localhost:3100/ready      # Loki
curl -s http://localhost:3200/ready      # Tempo
```

## Run / deploy

No services in this folder. Bring up the stack from sibling folders, then return here for the query reference.

## Query / verify

### Metrics — RED method (PromQL)

```promql
# Rate (R) — requests per second
sum(rate(http_requests_total[5m]))

# Errors (E) — error ratio
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))

# Duration (D) — p95 latency from a histogram
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```

### Metrics — USE method (PromQL)

```promql
# Utilization — CPU
1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))

# Saturation — load average per core
node_load1 / count without (cpu, mode)(node_cpu_seconds_total{mode="idle"})

# Errors — disk / network
rate(node_disk_io_errors_total[5m])
rate(node_network_receive_errs_total[5m])
```

### Golden Signals (one liner each)

```promql
sum(rate(http_requests_total[5m]))                                       # Traffic
sum(rate(http_requests_total{status=~"5.."}[5m]))                        # Errors
histogram_quantile(0.99, sum by (le)(rate(http_request_duration_seconds_bucket[5m])))  # Latency
1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))                   # Saturation
```

### Logs (LogQL)

```logql
{app="api"} |= "error"                            # contains
{app="api"} | json | status >= 500                # parsed field filter
sum(rate({app="api"} |= "error" [5m]))            # error rps from logs
```

### Traces (TraceQL)

```json
{ resource.service.name="checkout-svc" && status=error }
{ duration > 500ms }
```

### Bridge between pillars

```logql
# From a slow trace, jump to its logs
{app="api"} | json | trace_id="abc123def456"
```

## Inspect

```bash
# Confirm a service is emitting all three signals
curl -s http://APP:8080/metrics | head            # metrics endpoint live
curl -s http://APP:8080/healthz                   # liveness
# Logs: kubectl logs / docker logs SERVICE --tail=20
# Traces: open Grafana Explore -> Tempo, search by service.name
```

## Cleanup

Nothing to clean — this folder ships no runtime.

## One-liners worth memorising

```promql
# Error budget burn (per-minute)
1 - sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Always alert on rate(), never on raw counters
rate(http_requests_total[5m])

# p50 / p95 / p99 in one expression
histogram_quantile(0.5,  sum by (le)(rate(X_bucket[5m])))
histogram_quantile(0.95, sum by (le)(rate(X_bucket[5m])))
histogram_quantile(0.99, sum by (le)(rate(X_bucket[5m])))
```

```text
RED  -> services  (Rate, Errors, Duration)
USE  -> resources (Utilization, Saturation, Errors)
4 Golden Signals -> Latency, Traffic, Errors, Saturation
trace_id is the bridge between metrics, logs and traces.
```
