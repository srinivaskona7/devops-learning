# Cost & Cardinality — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm a Prometheus we can audit
curl -s http://localhost:9090/-/ready
```

## Run / deploy

No services here — this folder is operational hygiene. The interesting installs are alternatives to vanilla Prometheus retention:

```bash
# Thanos sidecar (federate + ship blocks to S3)
helm install thanos bitnami/thanos -n monitoring -f thanos-values.yaml

# Mimir (replace Prometheus storage with scalable backend)
helm install mimir grafana/mimir-distributed -n monitoring -f mimir-values.yaml

# VictoriaMetrics (lightweight single-binary or cluster)
docker run -d --name vm -p 8428:8428 \
  -v vm-data:/victoria-metrics-data \
  victoriametrics/victoria-metrics:latest
```

## Query / verify (cardinality audits)

```promql
# Top 20 metrics by series count
topk(20, count by (__name__)({__name__=~".+"}))

# Top label values for a specific metric
topk(20, count by (path)(http_requests_total))

# Series produced per job
sum by (job)({__name__=~".+"})

# Active series total
count({__name__=~".+"})

# Churn (high churn = labels with timestamps/IDs sneaking in)
rate(prometheus_tsdb_head_series_created_total[5m])
```

### TSDB stats endpoint (fastest cardinality view)

```bash
curl -s http://localhost:9090/api/v1/status/tsdb | jq '{
  totalSeries,
  topSeries: .data.seriesCountByMetricName[0:10],
  topLabels: .data.labelValueCountByLabelName[0:10],
  topLabelPairs: .data.seriesCountByLabelValuePair[0:10]
}'
```

## Inspect — drop noisy stuff

```yaml
# In prometheus.yml — drop runaway label values at scrape time
scrape_configs:
  - job_name: noisy-app
    metric_relabel_configs:
      - action: labeldrop
        regex: 'pod_template_hash|controller_revision_hash|.*uuid'
      - source_labels: [__name__]
        regex: 'app_request_duration_seconds_bucket'
        action: drop
```

```bash
# Hot reload after editing
curl -X POST http://localhost:9090/-/reload

# Verify it took effect
curl -s 'http://localhost:9090/api/v1/series?match[]=app_request_duration_seconds_bucket' | jq '.data | length'
```

### Increase scrape interval (15s -> 60s halves volume)

```yaml
global:
  scrape_interval: 60s
```

### Aggregate via recording rules before long-term storage

```yaml
groups:
  - name: aggregations
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job)(rate(http_requests_total[5m]))
```

## Long-term storage choice

```text
Thanos          -> keep your Prometheus servers, federate after the fact (sidecar -> S3 -> compactor downsamples).
Mimir (Grafana) -> replace Prometheus storage entirely; remote_write; billions of series.
Cortex          -> Mimir's predecessor; use Mimir.
VictoriaMetrics -> lower resource footprint single-binary or cluster.
```

## Cleanup

```bash
# Drop a runaway metric retroactively
promtool tsdb delete --match='{__name__="http_requests_total",path=~".+"}' /var/lib/prometheus
# Then snapshot + restart, or rely on retention to age it out.
```

## One-liners worth memorising

```bash
# The cardinality fire-alarm
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[0:5]'

# "What's killing my Prometheus right now?"
topk(10, count by (__name__)({__name__=~".+"}))

# Drop everything matching a pattern
metric_relabel_configs:
  - action: labeldrop
    regex: '.*_id$|.*uuid.*'
```

```text
Cardinality = unique label combos = active series. Million users in a label = million series = OOM.
Bounded label sets only. Method/status/region OK. user_id/request_id/trace_id NEVER (use logs+traces).
Cost levers (most -> least impact):
  1. Reduce active series (label hygiene)
  2. Increase scrape interval
  3. Shorten retention; offload to Thanos/Mimir + S3
  4. Drop high-cardinality histogram buckets
  5. Sample traces aggressively at the collector
```
