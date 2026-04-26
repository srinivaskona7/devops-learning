# OpenTelemetry — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
ls otel-collector.yaml otel-collector-config.yaml 2>/dev/null
# In k8s, the file is the ConfigMap source for the Collector Deployment.
```

## Run / deploy

```bash
# Local contrib collector — accepts OTLP gRPC :4317 + HTTP :4318
docker run --rm -p 4317:4317 -p 4318:4318 \
  -v $PWD/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml \
  otel/opentelemetry-collector-contrib:0.110.0

# Validate config without running pipelines
docker run --rm \
  -v $PWD/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml \
  otel/opentelemetry-collector-contrib:0.110.0 validate \
  --config=/etc/otelcol-contrib/config.yaml
```

### k8s deployment patterns

```
Sidecar    -> per-pod, lowest latency, per-app sampling
DaemonSet  -> per-node, default for k8s, picks up host metrics
Gateway    -> cluster service, tail sampling, multi-tenant routing

Most prod: DaemonSet -> Gateway -> backends (Prom / Tempo / Loki)
```

```bash
kubectl apply -f otel-collector.yaml -n observability
kubectl -n observability rollout status deploy/otel-collector
```

## Query / verify

```bash
# Send a sample OTLP trace via HTTP/protobuf (4318)
curl -i http://localhost:4318/v1/traces \
  -H 'Content-Type: application/json' \
  -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"smoke"}}]},"scopeSpans":[{"spans":[{"traceId":"5b8aa5a2d2c872e8321cf37308d69df2","spanId":"051581bf3cb55c13","name":"hello","startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000001000000000"}]}]}]}'

# Confirm exporters are flowing — collector self-metrics
curl -s http://localhost:8888/metrics | grep -E 'otelcol_(receiver|exporter)_'

# Health & zPages
curl -s http://localhost:13133/                     # health_check extension
open http://localhost:55679/debug/tracez            # zpages extension (live spans)
```

### Semantic conventions to use (don't invent your own)

```
service.name, service.version, deployment.environment
http.request.method, http.response.status_code, url.path
db.system, db.statement, messaging.system
```

## Inspect

```bash
# Pipeline stats — accepted/refused/dropped per signal
curl -s http://localhost:8888/metrics | grep -E 'accepted_spans|refused_spans|dropped'

# kubectl
kubectl -n observability logs deploy/otel-collector --tail=100 | grep -iE 'error|drop'
kubectl -n observability get cm otel-collector -o yaml | yq '.data."config.yaml"'
```

## Cleanup

```bash
# Local
docker ps -q --filter ancestor=otel/opentelemetry-collector-contrib:0.110.0 | xargs -r docker rm -f

# k8s
kubectl delete -f otel-collector.yaml -n observability
```

## One-liners worth memorising

```bash
otelcol-contrib validate --config=config.yaml         # lint
curl -s localhost:8888/metrics | grep otelcol_exporter_send_failed_spans_total
```

```
Apps speak OTLP to a LOCAL collector. Never let apps talk to backends directly.
OTLP -> 4317 (gRPC, preferred) | 4318 (HTTP/protobuf)
Use semantic conventions verbatim — that's how shared dashboards work.
Tail sampling = collector job, not app job.
```
