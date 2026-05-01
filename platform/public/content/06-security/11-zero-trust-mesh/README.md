# 11 - Zero Trust Service Mesh

**Zero trust** = no implicit trust based on network location. Every request is authenticated and authorised, even pod-to-pod inside the cluster. Service mesh (Istio, Linkerd) is the standard implementation.

## Identity flow (SPIFFE)

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-README-1-7fa9f8d6.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant Pod as Pod (workload A)
    participant Side as Envoy sidecar
    participant CP as Mesh control plane<br/>(istiod / linkerd identity)
    participant SVID as SVID / cert<br/>(SPIFFE ID)
    participant PodB as Pod B (workload B)

    Pod->>Side: HTTP request to PodB
    Side->>CP: request workload identity (mTLS bootstrap)
    CP->>Side: issue X.509 SVID<br/>(spiffe://cluster.local/ns/foo/sa/web)
    Side->>PodB: mTLS handshake<br/>presents SVID
    PodB->>Side: presents its SVID
    Side->>Side: AuthorizationPolicy check<br/>(identity, method, path)
    alt allowed
        Side->>PodB: forward request
    else denied
        Side->>Pod: 403 RBAC denied
    end
```

</details>
## Building blocks

| Concept | What it is |
|---------|-----------|
| **mTLS** | Mutual TLS — both sides present certs. Mesh handles cert issuance + rotation automatically. |
| **SPIFFE ID** | Universal workload identity URI — `spiffe://trust-domain/ns/<ns>/sa/<sa>`. Same ID can be used across mesh / Vault / cloud IAM. |
| **SPIRE** | Reference SPIFFE implementation — node + workload attestor that issues SVIDs. |
| **AuthorizationPolicy** | Mesh-native L7 policy — "ServiceAccount X may POST /api/orders to Y" |
| **PeerAuthentication** | Mesh-wide mTLS mode — `STRICT` mandates mTLS for all in-mesh traffic |

## Mesh comparison

| | Istio | Linkerd |
|---|-------|---------|
| Data plane | Envoy sidecar (or ambient) | linkerd2-proxy (Rust, lightweight) |
| Identity | SPIFFE | SPIFFE (since 2.x) |
| L7 features | Rich (JWT, ext-authz, WASM) | Focused, less surface |
| Ops complexity | High | Low |
| When | Need fine-grained policy, multi-cluster, gateway features | Want mTLS + observability with minimal ops |

## Files
- `istio-authz-policy.yaml` — STRICT mTLS + AuthorizationPolicy that denies by default and allows specific service-to-service calls

## Practical zero-trust adoption

1. Install mesh; enable mTLS in `PERMISSIVE` mode (mesh + non-mesh both work)
2. Inject sidecars into all namespaces
3. Watch metrics — once 100% mTLS, flip to `STRICT`
4. Add a default-deny `AuthorizationPolicy` at the namespace level
5. Add allow rules per service-to-service edge — your call graph becomes documented in YAML
