# Architecture Deep-Dive · Platform Engineering Capstone

This document traces every data path, control plane interaction, and failure mode across the six platform layers.

---

## Layer 1 · Developer Experience Layer

```mermaid
flowchart LR
    ENG[Engineer] -->|1. git push| PR[Pull Request]
    PR -->|2. CI triggered| CI_BUILD[Build + Test<br/>GitHub Actions]
    CI_BUILD -->|3. image built| TRIVY[Trivy scan<br/>no critical CVEs]
    TRIVY -->|4. scan pass| COSIGN_SIGN[cosign sign --keyless<br/>OIDC token from GHA]
    COSIGN_SIGN -->|5. push signed image| REGISTRY[OCI Registry<br/>ghcr.io]
    COSIGN_SIGN -->|6. update image tag| GITOPS_PR[GitOps repo PR<br/>auto-merged by bot]
    GITOPS_PR -->|7. ArgoCD detects diff| ARGOCD[Argo CD<br/>sync]
```

**Key decisions:**
- Keyless Cosign signing uses GitHub Actions OIDC token — no private key to manage or rotate
- GitOps PR is auto-merged only when the image scan attestation is present
- The engineer interacts with exactly one system: GitHub. Everything else is automated.

---

## Layer 2 · Delivery Layer (GitOps + Canary)

```mermaid
flowchart TB
    subgraph ArgoCD["Argo CD Control Plane"]
        AOA[app-of-apps<br/>root Application] -->|owns| DELAPP[delivery-app<br/>Application]
        AOA -->|owns| OBSAPP[observability-app]
        AOA -->|owns| SECAPP[security-app]
        AOA -->|owns| PLATAPP[platform-app]
        AOA -->|owns| CHAOSAPP[chaos-app]
    end

    subgraph Rollout["Argo Rollouts — payment-service"]
        DELAPP -->|syncs| ROLLOUTOBJ[Rollout object]
        ROLLOUTOBJ -->|step 1: weight 10| CANARY[Canary pods<br/>1 replica]
        ROLLOUTOBJ -->|maintains| STABLE[Stable pods<br/>2 replicas]
        CANARY -->|creates| ANALYSISRUN[AnalysisRun<br/>every 60s]
        ANALYSISRUN -->|queries| PROM[Prometheus<br/>error_rate + p95]
        ANALYSISRUN -->|5× pass → weight 25| STEP2[Weight 25%]
        STEP2 -->|5× pass → weight 50| STEP3[Weight 50%]
        STEP3 -->|5× pass → weight 100| PROMOTED[Promoted ✔]
        ANALYSISRUN -->|any fail| ROLLBACK[Rollback ✗]
    end

    subgraph Istio["Istio Traffic Management"]
        VS[VirtualService] -->|weight stable| STASVC[payment-service-stable]
        VS -->|weight canary| CANSVC[payment-service-canary]
        STASVC --> STABLE
        CANSVC --> CANARY
    end
```

**Canary strategy parameters:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Initial canary weight | 10% | Low blast radius for first exposure |
| Step progression | 10→25→50→100 | Non-linear — jumps fast once confidence builds |
| Analysis interval | 60s | Fast feedback without noise from single-request spikes |
| Consecutive passes required | 5 | 5 minutes of clean data before promoting |
| Error rate threshold | 0.1% (gold), 0.5% (silver), 1% (bronze) | Tier-appropriate |
| Rollback trigger | Any single analysis failure | Fail-fast; do not wait for sustained failure |

---

## Layer 3 · Runtime Layer (Kubernetes + Istio)

```mermaid
flowchart TB
    subgraph Cluster["Kubernetes Cluster (kind / EKS)"]
        subgraph SystemNS["system namespaces"]
            ARGOCD_NS[argocd]
            ISTIO_NS[istio-system]
            MONITOR_NS[monitoring]
            VAULT_NS[vault]
            ESO_NS[external-secrets]
            KYVERNO_NS[kyverno]
            CHAOS_NS[chaos-mesh]
            BACK_NS[backstage]
        end

        subgraph AppNS["application namespaces"]
            PAY_NS[payment namespace]
            FRAUD_NS[fraud namespace]
        end

        subgraph Networking["Istio Service Mesh"]
            direction LR
            PILOT[istiod<br/>control plane] -->|xDS config| ENVOY1[Envoy sidecar<br/>payment-service]
            PILOT -->|xDS config| ENVOY2[Envoy sidecar<br/>fraud-service]
            ENVOY1 <-->|mTLS 1.3| ENVOY2
            IG[Istio Ingress<br/>Gateway] -->|TLS termination| ENVOY1
        end
    end
```

**mTLS enforcement:**

```yaml
# PeerAuthentication: STRICT mode means:
# - All pod-to-pod communication MUST use mTLS
# - Plain HTTP connections are rejected
# - Istio sidecar handles certificate rotation automatically (every 24h)
# - Certificate authority: Istio's built-in CA (Citadel)
```

---

## Layer 4 · Observability Layer

```mermaid
flowchart LR
    subgraph Instrumentation["Service Instrumentation"]
        SVC[Service<br/>Go/Python/Node] -->|OTLP gRPC| COLLECTOR
        ENVOY[Envoy sidecar] -->|access log| COLLECTOR
    end

    subgraph COLLECTOR["OTel Collector (DaemonSet)"]
        direction TB
        RECV[OTLP receiver<br/>:4317] --> PROC[Batch processor<br/>+ resource detector]
        PROC --> EXP1[Prometheus exporter<br/>remote_write]
        PROC --> EXP2[Loki exporter<br/>HTTP push]
        PROC --> EXP3[OTLP exporter<br/>→ Tempo]
    end

    subgraph Backends
        PROM_TSDB[(Prometheus TSDB<br/>30d retention)]
        LOKI_STORE[(Loki<br/>S3/minio 90d)]
        TEMPO_STORE[(Tempo<br/>S3/minio 7d)]
    end

    subgraph Grafana["Grafana (unified)"]
        DS_PROM[Prometheus datasource]
        DS_LOKI[Loki datasource]
        DS_TEMPO[Tempo datasource]
        DASH[Service dashboard<br/>RED + USE + SLO]
        ALERTS[Alert rules<br/>+ Alertmanager]
        DS_PROM --> DASH
        DS_LOKI --> DASH
        DS_TEMPO --> DASH
        DASH --> ALERTS
    end

    EXP1 --> PROM_TSDB
    EXP2 --> LOKI_STORE
    EXP3 --> TEMPO_STORE
    PROM_TSDB --> DS_PROM
    LOKI_STORE --> DS_LOKI
    TEMPO_STORE --> DS_TEMPO
```

**Trace correlation:** Every log line emitted by instrumented services includes `trace_id` and `span_id`. Loki's `derived fields` configuration detects these automatically and renders a "View in Tempo" link in Grafana, allowing one-click navigation from a log line to its trace waterfall.

**Recording rules pre-compute:**
- `job:http_requests:rate5m` — per-job request rate
- `job:http_errors:rate5m` — per-job error rate
- `job:http_request_duration_p95:5m` — p95 latency
- `job:slo_error_budget_remaining:ratio` — error budget burn

---

## Layer 5 · Security Layer

```mermaid
flowchart TB
    subgraph Supply["Supply Chain Security"]
        CODE[Source code] -->|git push| GHA[GitHub Actions]
        GHA -->|build| IMG[Container image]
        IMG -->|trivy scan| SCAN_RESULT{critical CVEs?}
        SCAN_RESULT -->|yes| BLOCK[Block push ✗]
        SCAN_RESULT -->|no| SYFT[syft SBOM]
        SYFT -->|cosign attest| REGISTRY[(OCI Registry)]
        GHA -->|cosign sign --keyless| REGISTRY
    end

    subgraph Admission["Admission Control"]
        REGISTRY -->|image ref| DEPLOY[kubectl apply]
        DEPLOY --> KYVER_WEBHOOK[Kyverno webhook<br/>validating]
        KYVER_WEBHOOK -->|cosign verify| SIG_CHECK{signature valid?}
        SIG_CHECK -->|no| REJECT[Reject admission ✗]
        SIG_CHECK -->|yes| POLICY_CHECK{all policies pass?}
        POLICY_CHECK -->|no| REJECT2[Reject admission ✗]
        POLICY_CHECK -->|yes| SCHEDULE[Schedule pod ✔]
    end

    subgraph Secrets["Secrets Management"]
        VAULT_SRV[HashiCorp Vault] -->|dynamic secret lease| ESO_CTRL[External Secrets<br/>Operator controller]
        ESO_CTRL -->|creates/rotates| K8S_SEC[Kubernetes Secret]
        K8S_SEC -->|envFrom| POD_ENV[Pod environment]
        VAULT_SRV -->|PKI cert| MTLS_CERT[mTLS certificate<br/>(via Istio CA)]
    end
```

**Defense layers:**

| Layer | Control | What it prevents |
|-------|---------|-----------------|
| Build | Trivy image scan | Known CVEs reaching production |
| Build | Cosign keyless sign | Supply chain tampering |
| Admission | Kyverno 5 policies | Misconfigured workloads deploying |
| Admission | Cosign verify policy | Unsigned/tampered images running |
| Runtime | Istio mTLS STRICT | Pod-to-pod traffic interception |
| Runtime | Istio AuthorizationPolicy | Lateral movement between namespaces |
| Secrets | Vault + ESO | Plaintext secrets in git |
| Secrets | 24h lease rotation | Long-lived credential compromise |

---

## Layer 6 · Chaos Engineering Layer

```mermaid
flowchart LR
    subgraph Experiments["Chaos Mesh Experiments"]
        SCHED[CronChaos<br/>schedule: daily 03:00 UTC] -->|spawns| E1[PodChaos<br/>pod-kill]
        SCHED -->|spawns| E2[NetworkChaos<br/>100ms delay]
        SCHED -->|spawns| E3[StressChaos<br/>CPU 80%]
    end

    subgraph Observation["Concurrent Observation"]
        K6_RUNNER[k6 load generator<br/>500 VUs] -->|measures| METRICS[p95 latency<br/>error rate<br/>throughput]
        PROM_QUERY[Prometheus<br/>alerting] -->|SLO breach?| NOTIFY[PagerDuty alert]
    end

    subgraph Recovery["Platform Recovery Mechanisms"]
        E1 -->|pod terminated| KUBE_SCHED[Kubernetes reschedules<br/>in ~10s]
        E2 -->|packets delayed| RETRY[Client retry<br/>with exponential backoff]
        E3 -->|CPU throttled| HPA[HPA scales out<br/>within 60s]
    end

    Experiments --> Observation
    Recovery --> Observation
```

**Hypothesis format** (per game day):

```
Hypothesis: "When 1 of 3 payment-service pods is killed,
             p95 latency will remain below 150ms (gold SLO)
             and error rate will remain 0%
             within 30 seconds of the kill event."

Steady state:  p95=80ms, error=0%, 3/3 pods Running
Experiment:    Kill pod payment-service-7d9f8b-xxxxx
Expected:      Kubernetes reschedules; client retries succeed
Measured:      p95=94ms peak (14s), recovered to 82ms by 27s
Result:        PASS — hypothesis confirmed
```

---

## Failure mode analysis

| Failure | Detection | Automated response | Manual action if needed |
|---------|-----------|-------------------|------------------------|
| Canary SLO breach | AnalysisRun | Auto-rollback | `argo rollouts abort` |
| Pod crash | Kubernetes liveness probe | Restart + reschedule | Check logs: `kubectl logs` |
| Node failure | Node `NotReady` | Workloads reschedule | Drain node, investigate |
| Vault unreachable | ESO sync error | Existing secrets remain | Manual: `vault status` |
| Registry unreachable | Image pull failure | Pod stays on old image | Check registry health |
| Kyverno webhook timeout | Admission webhook timeout | Cluster configured `failOpen=false` → block all deployments | Disable webhook, fix, re-enable |
| Istio CA cert expiry | Envoy TLS handshake failure | Istiod auto-rotates certs | `istioctl check-inject` |
| Loki storage full | Log drops | Alert fires | Expand storage or reduce retention |

---

## Network topology

```
External traffic
       │
       ▼
[Cloud Load Balancer]  ← or kind NodePort for local
       │
       ▼
[Istio Ingress Gateway]  ← TLS termination, cert managed by cert-manager
       │  HTTPS→HTTP (within mesh, mTLS re-established by Envoy)
       ▼
[VirtualService]  ← canary weight split
  ├── [payment-service stable]  ← ClusterIP
  └── [payment-service canary]  ← ClusterIP

Internal (service mesh):
[payment-service] ──mTLS──► [fraud-service]  ← AuthorizationPolicy enforced
[payment-service] ──mTLS──► [postgres]       ← DB traffic also in mesh
```

---

## Data flow — secret injection

```
1. CI/CD writes: vault kv put secret/payment-service/db-password value=<generated>
2. ExternalSecret controller polls Vault every 3600s (or on-demand)
3. ESO creates/updates Kubernetes Secret: payment-service-db
   - Secret data is base64-encoded, stored in etcd (etcd should be encrypted at rest)
4. Pod spec uses: envFrom: - secretRef: name: payment-service-db
5. Kubelet injects secret as environment variable at pod start
6. When Vault lease expires (24h), ESO auto-rotates:
   a. Vault generates new value
   b. ESO updates Kubernetes Secret
   c. Kubernetes rolling restart (triggered by pod annotation hash change)
   d. New pods start with new secret; old pods terminate gracefully
```

---

## Deployment topology diagram

```
kind cluster (local) or EKS cluster (cloud)
│
├── Node 1 (control-plane)
│   ├── kube-apiserver
│   ├── etcd (encrypted at rest)
│   ├── kube-scheduler
│   └── kube-controller-manager
│
├── Node 2 (worker)
│   ├── argocd (argocd ns)
│   ├── vault (vault ns)
│   ├── external-secrets (external-secrets ns)
│   └── kyverno (kyverno ns)
│
├── Node 3 (worker)
│   ├── istiod (istio-system ns)
│   ├── istio-ingressgateway (istio-system ns)
│   ├── prometheus (monitoring ns)
│   └── grafana (monitoring ns)
│
└── Node 4 (worker)
    ├── loki (monitoring ns)
    ├── tempo (monitoring ns)
    ├── chaos-mesh (chaos-mesh ns)
    ├── backstage (backstage ns)
    └── payment-service (payment ns) ← application workloads
```
