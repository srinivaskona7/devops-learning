# Loki — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
ls loki-config.yaml promtail-config.yaml
docker network create obs 2>/dev/null
```

## Run / deploy

```bash
# Loki single-binary
docker run -d --name loki --network obs -p 3100:3100 \
  -v $PWD/loki-config.yaml:/etc/loki/local-config.yaml \
  grafana/loki:3.2.0 -config.file=/etc/loki/local-config.yaml

# Promtail (DaemonSet equivalent on a single host)
docker run -d --name promtail --network obs \
  -v $PWD/promtail-config.yaml:/etc/promtail/config.yml \
  -v /var/log:/var/log:ro \
  grafana/promtail:3.2.0 -config.file=/etc/promtail/config.yml

# In k8s, prefer Grafana Alloy (logs+metrics+traces in one binary, OTel-native)
```

## Query / verify (LogQL)

```bash
# Ready check
curl -s http://localhost:3100/ready
curl -s http://localhost:3100/metrics | grep loki_build_info

# Push test line
curl -s -H "Content-Type: application/json" -XPOST http://localhost:3100/loki/api/v1/push \
  --data-raw '{"streams":[{"stream":{"app":"smoke"},"values":[["'$(date +%s)000000000'","hello"]]}]}'

# Query — instant
curl -sG http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={app="smoke"}' | jq .

# Query — range
curl -sG http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={app="api"} |= "error"' \
  --data-urlencode "start=$(date -u -v-1H +%s)000000000" \
  --data-urlencode "end=$(date -u +%s)000000000" | jq .

# Discovery
curl -s http://localhost:3100/loki/api/v1/labels | jq .
curl -s http://localhost:3100/loki/api/v1/label/app/values | jq .
```

### LogQL cheats

```logql
{namespace="prod", app="api"}                       # selector
{app="api"} |= "error"                              # contains
{app="api"} != "healthcheck"                        # excludes
{app="api"} |~ "5\\d\\d"                            # regex
{app="api"} | json                                  # parse JSON
{app="api"} | logfmt                                # parse k=v
{app="api"} | json | status >= 500 | duration > 1s  # filter parsed fields
sum(rate({app="api"} |= "error" [5m]))              # metric from logs
sum by (status) (count_over_time({app="api"} | json [5m]))
```

### logcli (CLI client)

```bash
export LOKI_ADDR=http://localhost:3100
logcli labels
logcli query '{app="api"} |= "error"' --since=1h --limit=50
logcli series '{app="api"}'
```

## Inspect

```bash
# Active stream count (cardinality red flag if huge)
curl -s http://localhost:3100/metrics | grep loki_ingester_memory_streams

# Promtail target discovery
curl -s http://localhost:9080/targets | jq .
docker logs -f promtail | grep -i 'error\|target'

# Disk / chunk dir
docker exec loki ls -lh /loki
```

## Cleanup

```bash
docker rm -f loki promtail
docker network rm obs 2>/dev/null
```

## One-liners worth memorising

```bash
logcli query '{namespace="prod"} |= "panic"' --since=24h
curl -s localhost:3100/loki/api/v1/labels | jq '.data | length'
```

```text
Index labels only. NEVER label by user_id / request_id / trace_id — keep them in the line, parse with | json.
Aim for < 100k active streams per tenant.
Promtail still works; new deployments -> Grafana Alloy.
Loki vs ELK: cheaper storage (S3 + gzip chunks), slower free-text search.
```
