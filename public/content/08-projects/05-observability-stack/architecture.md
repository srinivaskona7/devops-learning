# Architecture — Project 05: Observability Stack

## Layered signal flow

```mermaid
flowchart TB
  subgraph App["Application Layer"]
    direction LR
    API["FastAPI<br/>obs-demo"]
    SDK["OTel SDK<br/>traces · metrics · logs"]
    PROM_EP["/metrics<br/>Prometheus endpoint"]
    API --> SDK
    API --> PROM_EP
  end

  subgraph Collector["OTel Collector (DaemonSet-equivalent)"]
    direction LR
    RECV["OTLP Receiver<br/>gRPC :4317 · HTTP :4318"]
    MEM_LIM["memory_limiter<br/>256 MiB"]
    BATCH["batch processor<br/>1024 spans / 5s"]
    RES["resource enricher<br/>k8s.cluster.name"]
    RECV --> MEM_LIM --> BATCH --> RES
  end

  subgraph Backends["Signal Backends"]
    direction TB
    TEMPO["Tempo<br/>single-binary<br/>TraceQL"]
    LOKI["Loki<br/>single-binary<br/>LogQL"]
    PROM["Prometheus<br/>kube-prom-stack<br/>PromQL + remote-write receiver"]
  end

  subgraph Grafana["Grafana Dashboards"]
    direction LR
    GS["Four Golden Signals<br/>Rate · Errors · Duration · Saturation"]
    SLO["SLO Burn-Rate<br/>5% · 2% windows"]
    DS["Pre-wired datasources<br/>Prometheus · Loki · Tempo"]
    GS --- DS
    SLO --- DS
  end

  SDK -->|"OTLP gRPC"| RECV
  PROM_EP -->|"Prometheus scrape"| PROM

  RES -->|"OTLP gRPC"| TEMPO
  RES -->|"Loki push API"| LOKI
  RES -->|"remote_write"| PROM

  PROM -->|"PromQL"| DS
  LOKI -->|"LogQL"| DS
  TEMPO -->|"TraceQL"| DS

  style App fill:#1e3a5f,color:#e2e8f0
  style Collector fill:#2d4a22,color:#e2e8f0
  style Backends fill:#3d2a1e,color:#e2e8f0
  style Grafana fill:#3d1e3d,color:#e2e8f0
```

## Exemplar link — the three-pillar correlation

```mermaid
sequenceDiagram
  autonumber
  participant Client
  participant App as FastAPI (obs-demo)
  participant OTelSDK as OTel SDK
  participant Collector as OTel Collector
  participant Tempo
  participant Loki
  participant Prometheus
  participant Grafana

  Client->>App: GET /slow
  App->>OTelSDK: start span "slow-handler"
  App->>OTelSDK: emit log {trace_id, span_id, msg}
  App->>OTelSDK: record histogram{duration, trace_id as exemplar}
  App-->>Client: 200 OK

  OTelSDK->>Collector: OTLP batch (spans + metrics + logs)
  Collector->>Tempo: forward span
  Collector->>Loki: forward log line (label: trace_id)
  Collector->>Prometheus: remote-write metric + exemplar{trace_id}

  Note over Grafana: User clicks exemplar on latency panel
  Grafana->>Prometheus: query exemplar trace_id
  Grafana->>Tempo: GET /api/traces/{trace_id}
  Grafana->>Loki: query {trace_id="..."}
  Note over Grafana: All three pillars resolved from ONE trace_id
```

## Design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Signal transport | OTLP gRPC to OTel Collector | Vendor-neutral; Collector handles fan-out so the app has one dependency |
| Collector placement | Deployment (not DaemonSet) | Simpler in kind; upgrade to DaemonSet for node-level host metrics in production |
| Metrics path | OTel SDK → Collector → Prometheus remote-write AND direct Prometheus scrape | Dual path ensures metrics survive Collector restarts; exemplars only flow via remote-write |
| Log correlation | OTel LoggingInstrumentor patches Python `logging` to inject `trace_id` and `span_id` into every log record | Zero application code change needed; works with existing `logger.info()` calls |
| Exemplars | Histogram datapoints carry `trace_id` as an exemplar label | Enables click-to-trace from Grafana latency panels without manual search |
| Storage | Local filesystem (kind) | No object-store dependency for local development; swap to S3/GCS for production by changing `storage.type` in Tempo/Loki values |
| SLO model | Google SRE multi-window burn-rate (1h/5m + 6h/30m) | Catches both fast incident spikes and slow budget leaks; matches the Prometheus alerting standard |

## Port map

| Service | Port (forwarded) | Purpose |
|---------|-----------------|---------|
| obs-demo | 8000 | Application HTTP + `/metrics` |
| OTel Collector gRPC | 4317 | OTLP receive |
| OTel Collector HTTP | 4318 | OTLP receive (HTTP) |
| OTel Collector metrics | 8888 | Collector self-telemetry |
| Prometheus | 9090 | Query + remote-write |
| Loki | 3100 | Push + query |
| Tempo | 3200 | Trace query (Grafana) / 3100 trace ingest |
| Grafana | 3000 | Dashboards |

## Component versions

| Component | Version | Notes |
|-----------|---------|-------|
| FastAPI | 0.111.0 | ASGI, auto OTel instrumentation |
| OTel SDK (Python) | 1.24.0 | Latest stable |
| OTel Collector Contrib | 0.100.0 | Loki exporter only in contrib |
| Prometheus | 2.50+ | Via kube-prom-stack 58.x |
| Loki | 3.x | Via Helm chart 6.6.x |
| Tempo | 2.4.x | Via Helm chart 1.9.x |
| Grafana | 10.x | Via kube-prom-stack |
