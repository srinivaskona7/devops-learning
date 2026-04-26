# SLO Engineering — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
ls slo-rules.yaml

# Sloth (CLI generator)
brew install slok/tap/sloth   # or: go install github.com/slok/sloth/cmd/sloth@latest
sloth version
```

## Run / deploy

### Sloth (compile SLO YAML -> Prometheus rules)

```bash
sloth generate -i slo-rules.yaml -o /tmp/slo-prom-rules.yaml
sloth validate -i slo-rules.yaml

# Drop the generated rules into Prometheus
cp /tmp/slo-prom-rules.yaml /etc/prometheus/rules/
curl -X POST http://localhost:9090/-/reload
```

### Pyrra (operator + UI alternative)

```bash
kubectl apply -f https://github.com/pyrra-dev/pyrra/releases/latest/download/manifests.yaml
kubectl -n monitoring apply -f slo-rules.yaml         # PrometheusServiceLevel CR
kubectl -n monitoring port-forward svc/pyrra 9099
# UI: http://localhost:9099
```

## Query / verify (PromQL)

```promql
# Error budget remaining (28d)
1 - (
  sum(rate(http_requests_total{status=~"5.."}[28d]))
  /
  sum(rate(http_requests_total[28d]))
) / 0.001                                    # 0.001 = 1 - 0.999 SLO

# Burn rate (1h window) — multiplier of allowed bad rate
(sum(rate(http_requests_total{status=~"5.."}[1h]))
  / sum(rate(http_requests_total[1h])))
  / 0.001
```

### Multi-window, multi-burn-rate alert thresholds

```
Page    14.4x   long=1h   short=5m    burn budget in 2 days
Page     6x     long=6h   short=30m   burn budget in 5 days
Ticket   3x     long=24h  short=2h    burn budget in 10 days
Ticket   1x     long=72h  short=6h    burn budget in 30 days
```

Both windows must breach simultaneously to fire — short window is the "fresh data" gate.

### Verify recording/alerting rules landed

```bash
curl -s http://localhost:9090/api/v1/rules | jq \
  '.data.groups[] | {name, rules: [.rules[].name]}'

curl -s http://localhost:9090/api/v1/alerts | jq \
  '.data.alerts[] | select(.labels.severity=="page")'
```

## Inspect

```bash
# Sloth output anatomy
yq '.groups[].rules[] | {record, alert}' /tmp/slo-prom-rules.yaml

# Pyrra status
kubectl -n monitoring get prometheusservicelevels.pyrra.dev
kubectl -n monitoring describe prometheusservicelevel <name>
```

## Common SLI shapes

```promql
# HTTP availability
sum(rate(http_requests_total{status!~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))

# Latency SLI (faster than 300ms)
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
  / sum(rate(http_request_duration_seconds_count[5m]))

# Job/queue success
sum(rate(jobs_processed_total{result="success"}[5m]))
  / sum(rate(jobs_processed_total[5m]))
```

## Cleanup

```bash
rm /etc/prometheus/rules/slo-prom-rules.yaml
curl -X POST http://localhost:9090/-/reload

# Pyrra
kubectl delete -f https://github.com/pyrra-dev/pyrra/releases/latest/download/manifests.yaml
```

## One-liners worth memorising

```bash
sloth validate -i slo-rules.yaml
sloth generate -i slo-rules.yaml | yq '.groups[].name'
```

```
SLI  = good / total                  (the measurement)
SLO  = target over a window           (e.g. 99.9% / 28d)
EB   = 1 - SLO                       (0.1% ~= 40m 19s/month)
Burn = bad_rate / (1 - SLO)          (multiplier vs allowed)

Don't aim for 100% — burn-out and zero feature velocity.
Don't average over a year — use 28d rolling.
Don't pick SLIs nobody outside engineering understands.
Pick Sloth OR Pyrra and stay consistent.
```
