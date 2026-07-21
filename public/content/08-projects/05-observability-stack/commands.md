# Project 05 (Observability Stack) — Commands

> Quick pickup reference. Full walkthrough in `README.md` and `walkthrough.md`.

## Prerequisites
```bash
kubectl top nodes                 # at least 4 vCPU / 8 GiB free
helm version
kubectl get sc                    # WaitForFirstConsumer SC available

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana              https://grafana.github.io/helm-charts
helm repo add open-telemetry       https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

## Build
Nothing to build — pure Helm install.

## Deploy
```bash
kubectl create namespace monitoring

# 1. kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm -n monitoring install kps prometheus-community/kube-prometheus-stack \
  --version 62.6.0 \
  --set grafana.adminPassword='admin' \
  --set prometheus.prometheusSpec.retention=7d \
  --wait --timeout 10m

# 2. Loki (single-binary)
helm -n monitoring install loki grafana/loki \
  --version 6.16.0 \
  --set deploymentMode=SingleBinary \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set loki.auth_enabled=false \
  --set singleBinary.replicas=1

# 3. Tempo
helm -n monitoring install tempo grafana/tempo --version 1.10.3

# 4. OTel Collector
helm -n monitoring install otel open-telemetry/opentelemetry-collector \
  --version 0.108.0 \
  --set mode=deployment \
  --set image.repository=otel/opentelemetry-collector-contrib \
  -f - <<'EOF'
config:
  receivers:
    otlp:
      protocols:
        grpc: { endpoint: 0.0.0.0:4317 }
        http: { endpoint: 0.0.0.0:4318 }
  exporters:
    prometheus:    { endpoint: 0.0.0.0:8889 }
    otlphttp/loki: { endpoint: http://loki:3100/otlp }
    otlp/tempo:    { endpoint: tempo:4317, tls: { insecure: true } }
  service:
    pipelines:
      metrics: { receivers: [otlp], exporters: [prometheus] }
      logs:    { receivers: [otlp], exporters: [otlphttp/loki] }
      traces:  { receivers: [otlp], exporters: [otlp/tempo] }
EOF
```

## Verify
```bash
kubectl -n monitoring get pods       # all Running

# Grafana UI
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
# http://localhost:3000  (admin / admin)

# Prometheus targets
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
open http://localhost:9090/targets

# Generate traffic against the hello-world app then query:
#   sum(rate(container_cpu_usage_seconds_total{namespace="proj01"}[5m]))
```

## Cleanup
```bash
helm -n monitoring uninstall otel tempo loki kps
kubectl -n monitoring delete pvc --all
kubectl delete namespace monitoring
```

## One-liners worth memorising
```bash
# Get Grafana admin password (if you lost it)
kubectl -n monitoring get secret kps-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo

# Reload Prometheus config without restart
kubectl -n monitoring exec -it prometheus-kps-prometheus-0 -- \
  curl -X POST http://localhost:9090/-/reload

# Tail OTel collector logs
kubectl -n monitoring logs deploy/otel-opentelemetry-collector -f

# Quick LogQL probe from CLI
kubectl -n monitoring exec -it loki-0 -- \
  wget -qO- 'http://localhost:3100/loki/api/v1/labels'

# Generate sustained traffic for the walkthrough
for i in $(seq 1 200); do curl -s http://hello.local/ >/dev/null; sleep 0.2; done
```
