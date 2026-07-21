# PromQL Cheatsheet

## Selectors

```promql
http_requests_total                          # all series
http_requests_total{job="api"}               # label match
http_requests_total{status=~"5.."}           # regex
http_requests_total{status!~"2..|3.."}       # negative regex
http_requests_total{job="api"}[5m]           # range vector (last 5m of samples)
```

## Rate functions

| Function | When to use |
|----------|-------------|
| `rate(x[5m])` | Per-second avg over the window. **Use for alerting & dashboards.** |
| `irate(x[5m])` | Per-second rate from last 2 samples. **Volatile; only for graphs.** |
| `increase(x[1h])` | Total delta over the window (= `rate * window`). |
| `delta(x[5m])` | For gauges only. |
| `deriv(x[5m])` | Slope per second for gauges. |
| `predict_linear(x[1h], 4*3600)` | Extrapolate 4h ahead. Disk-fill alerts. |

`rate` and `irate` work on **counters only** and auto-handle counter resets.

## Aggregations

```promql
sum(rate(http_requests_total[5m]))                       # global rps
sum by (job) (rate(http_requests_total[5m]))             # rps per job
sum without (instance) (rate(http_requests_total[5m]))   # drop instance
avg, max, min, count, stddev, topk(5, ...), bottomk
```

`by` keeps listed labels. `without` drops listed labels. **Always pick one.**

## Histograms

```promql
# p99 latency
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# p99 per service
histogram_quantile(0.99,
  sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

**Always preserve `le` in the by-clause.** Always wrap the bucket in `rate()`.

## Time-window functions

```promql
avg_over_time(node_load1[10m])
max_over_time(...)
min_over_time(...)
sum_over_time(...)
quantile_over_time(0.95, ...)
stddev_over_time(...)
```

These work on **gauges**, not counters.

## Common queries

### Error ratio (RED)
```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))
```

### CPU % per node
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory % per node
```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

### Pod restart rate
```promql
sum by (namespace, pod) (rate(kube_pod_container_status_restarts_total[15m]))
```

### Top 10 namespaces by CPU
```promql
topk(10, sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace!=""}[5m])))
```

### Apdex-style "good ratio"
```promql
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
  /
sum(rate(http_request_duration_seconds_count[5m]))
```

## Operators

```promql
a + b   a - b   a * b   a / b   a % b   a ^ b
a == b  a != b  a > b   a >= b
a and b   a or b   a unless b   # set ops; match on labels
```

Use `on(...)` / `ignoring(...)` and `group_left` / `group_right` for many-to-one joins:

```promql
# Add a "team" label from kube_pod_labels onto a metric
sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))
  * on(pod) group_left(label_team)
kube_pod_labels
```

## Gotchas

- `rate()` needs **at least 4 samples** in the window — use a window ≥ 4× scrape interval.
- Don't `sum()` a counter directly. Always `rate()` first.
- `_count` and `_sum` from histograms can be `rate`d too — ratio gives mean latency.
- `up == 0` is the universal "is it scraping" check.
