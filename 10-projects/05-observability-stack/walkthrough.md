# Walkthrough — Instrument Project 01 with OpenTelemetry

## 1. Add the OTel SDK to `app/requirements.txt`

```txt
flask==3.0.3
gunicorn==22.0.0
opentelemetry-distro==0.48b0
opentelemetry-exporter-otlp==1.27.0
opentelemetry-instrumentation-flask==0.48b0
```

## 2. Auto-instrument at container start

Edit the Dockerfile `CMD`:

```dockerfile
RUN opentelemetry-bootstrap -a install
CMD ["opentelemetry-instrument", \
     "--traces_exporter", "otlp", \
     "--metrics_exporter", "otlp", \
     "--logs_exporter", "otlp", \
     "gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
```

## 3. Point the SDK at the collector

In `k8s/deployment.yaml` add to `env:`:

```yaml
- name: OTEL_SERVICE_NAME
  value: hello-world
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-opentelemetry-collector.monitoring.svc.cluster.local:4318
- name: OTEL_RESOURCE_ATTRIBUTES
  value: deployment.environment=dev,service.namespace=proj01
```

## 4. Generate traffic

```bash
for i in $(seq 1 200); do
  curl -s http://hello.local/ > /dev/null
  curl -s http://hello.local/healthz > /dev/null
  sleep 0.2
done
```

## 5. Explore in Grafana

### Metrics (Prometheus)
```
sum by (http_status_code) (
  rate(http_server_request_duration_seconds_count{service_name="hello-world"}[1m])
)
```

### Logs (Loki)
```
{service_name="hello-world"} |= "GET /"
```

### Traces (Tempo)
- Open **Explore → Tempo** → Service: `hello-world`
- Click any trace → view spans
- Click "Logs for this span" → jumps to Loki filtered by `trace_id`

## 6. Add an alert

Create `PrometheusRule`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: hello-world-slo
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: hello-world.rules
      rules:
        - alert: HelloWorldHighErrorRate
          expr: |
            sum(rate(http_server_request_duration_seconds_count{service_name="hello-world",http_status_code=~"5.."}[5m]))
              /
            sum(rate(http_server_request_duration_seconds_count{service_name="hello-world"}[5m])) > 0.05
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Hello-world error rate >5% for 10m"
```

## Common gotchas

| Symptom | Fix |
|---------|-----|
| No spans in Tempo | Check collector `traces` pipeline; `kubectl -n monitoring logs deploy/otel-opentelemetry-collector` |
| Metrics arrive but no `service_name` | Set `OTEL_SERVICE_NAME` env var |
| Logs show but no trace_id | Use `OpenTelemetryHandler` for stdlib logging or set `OTEL_PYTHON_LOG_CORRELATION=true` |
| Pod can't reach collector | DNS: confirm full FQDN with `kubectl run debug --image=busybox --rm -it -- nslookup otel-opentelemetry-collector.monitoring` |
