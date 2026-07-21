# Alerting (Alertmanager) — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
ls alertmanager.yaml

# Lint
docker run --rm -v $PWD:/cfg prom/alertmanager:v0.27.0 \
  amtool check-config /cfg/alertmanager.yaml
```

## Run / deploy

```bash
docker run -d --name alertmanager -p 9093:9093 \
  -v $PWD/alertmanager.yaml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager:v0.27.0 \
  --config.file=/etc/alertmanager/alertmanager.yml
# UI: http://localhost:9093

# Wire it up in prometheus.yml
# alerting:
#   alertmanagers:
#     - static_configs: [ { targets: ['alertmanager:9093'] } ]
```

## Query / verify

```bash
# Health
curl -s http://localhost:9093/-/ready
curl -s http://localhost:9093/api/v2/status | jq '.cluster, .versionInfo'

# Active alerts being managed
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | {labels, status: .status.state}'

# Send a synthetic alert (test routing without Prometheus)
curl -s -XPOST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d '[
  {"labels":{"alertname":"SmokeTest","severity":"critical","cluster":"local"},
   "annotations":{"summary":"manual test"},
   "startsAt":"'"$(date -u +%FT%TZ)"'"}
]'

# Test the route tree against your config (CLI)
amtool config routes test --config.file=alertmanager.yaml \
  severity=critical alertname=NodeDown
```

### Silences

```bash
# Create a 1h silence by label match
amtool silence add alertname=NoisyAlert --duration=1h \
  --comment "deploy in progress" --author=$USER \
  --alertmanager.url=http://localhost:9093

amtool silence query --alertmanager.url=http://localhost:9093
amtool silence expire <ID>  --alertmanager.url=http://localhost:9093
```

## Inspect

```bash
# View loaded config
curl -s http://localhost:9093/api/v2/status | jq '.config.original' -r

# Receivers
curl -s http://localhost:9093/api/v2/receivers | jq .

# Reload after editing config
curl -X POST http://localhost:9093/-/reload

# Logs
docker logs -f alertmanager | grep -iE 'error|notify|silence'
```

### Severity convention

```text
critical -> page now      -> PagerDuty + Slack
warning  -> next biz hour -> Slack
info     -> dashboard     -> none
```

## Cleanup

```bash
docker rm -f alertmanager
```

## One-liners worth memorising

```bash
amtool check-config alertmanager.yaml
amtool config routes show --config.file=alertmanager.yaml
curl -X POST http://localhost:9093/-/reload
```

```text
Prometheus FIRES alerts. Alertmanager ROUTES them.
Group by alertname,cluster,namespace -> one incident = one message.
Inhibition: NodeDown suppresses dependent PodNotReady noise.
Always require sustained breach with `for: 10m` -> no flaps.
Alert on user-visible symptoms, not raw causes (CPU high may be fine).
Email-only critical alerts = no one wakes up. Use PagerDuty/OpsGenie.
```
