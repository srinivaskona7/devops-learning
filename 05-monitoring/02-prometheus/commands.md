# Prometheus — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Files expected in CWD
ls prometheus.yml alert-rules.yml recording-rules.yml

# Validate config before running
docker run --rm -v $PWD:/cfg prom/prometheus:v2.54.1 \
  promtool check config /cfg/prometheus.yml

docker run --rm -v $PWD:/cfg prom/prometheus:v2.54.1 \
  promtool check rules /cfg/alert-rules.yml /cfg/recording-rules.yml
```

## Run / deploy

```bash
# Prometheus (pull-based scraper + TSDB + rule evaluator)
docker run -d --name prom -p 9090:9090 \
  -v $PWD/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v $PWD/alert-rules.yml:/etc/prometheus/alert-rules.yml \
  -v $PWD/recording-rules.yml:/etc/prometheus/recording-rules.yml \
  prom/prometheus:v2.54.1
# UI: http://localhost:9090

# Companion exporters
docker run -d --name node-exporter -p 9100:9100 \
  prom/node-exporter:v1.8.2

docker run -d --name alertmanager -p 9093:9093 \
  prom/alertmanager:v0.27.0

docker run -d --name pushgateway -p 9091:9091 \
  prom/pushgateway:v1.10.0

# Custom retention (default is 15d)
docker run -d --name prom -p 9090:9090 \
  -v $PWD/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:v2.54.1 \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.retention.time=30d
```

## Query / verify (PromQL)

```bash
# Instant query via HTTP API
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up' | jq .

# Range query
curl -sG http://localhost:9090/api/v1/query_range \
  --data-urlencode 'query=rate(http_requests_total[5m])' \
  --data-urlencode "start=$(date -u -v-1H +%s)" \
  --data-urlencode "end=$(date -u +%s)" \
  --data-urlencode 'step=30' | jq .

# Targets / scrape state
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, health}'

# Active alerts
curl -s http://localhost:9090/api/v1/alerts | jq .

# Rule evaluation status
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].name'
```

### PromQL patterns

```promql
up                                                  # which targets are up
rate(http_requests_total[5m])                       # per-second rate
sum by (job)(rate(http_requests_total[5m]))         # aggregated
histogram_quantile(0.95, sum by (le)(rate(http_request_duration_seconds_bucket[5m])))
topk(10, sum by (instance)(rate(node_cpu_seconds_total{mode!="idle"}[5m])))
```

### Push from a batch job

```bash
echo "batch_last_success_unixtime $(date +%s)" \
  | curl --data-binary @- http://localhost:9091/metrics/job/nightly_export
```

## Inspect

```bash
# Reload config without restart
curl -X POST http://localhost:9090/-/reload

# Build / version info
curl -s http://localhost:9090/api/v1/status/buildinfo | jq .

# TSDB head stats — series count, chunks
curl -s http://localhost:9090/api/v1/status/tsdb | jq .

# Cardinality — top label-value counts
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[0:20]'
```

## Cleanup

```bash
docker rm -f prom node-exporter alertmanager pushgateway
docker volume prune -f
```

## One-liners worth memorising

```bash
promtool check config prometheus.yml                # lint
promtool check rules *.yml                          # lint rules
curl -X POST http://localhost:9090/-/reload         # hot reload
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[].health' | sort | uniq -c
```

```
Pull beats push for long-running services.
Pushgateway is for short-lived/batch jobs ONLY.
Cardinality kills you, not volume.
Default retention 15d — change with --storage.tsdb.retention.time.
```
