# SPIFFE & SPIRE Deep Dive

## Why this matters

Zero-trust architectures need workload identity that doesn't depend on network location, IP allowlists, or shared secrets. SPIFFE (Secure Production Identity Framework For Everyone) defines the identity standard; SPIRE is the reference implementation. Together they let services prove who they are using cryptographic identities issued automatically based on platform attestation — no API keys to rotate, no certs to manage, mTLS that "just works" across clusters and clouds.

## Mental Model

Every workload gets a **SPIFFE ID** (a URI like `spiffe://acme.com/payments/api`). The platform proves what the workload is via **attestation** (k8s pod metadata, AWS instance identity doc, etc.), and SPIRE issues a short-lived **SVID** (SPIFFE Verifiable Identity Document) — either x509 (for mTLS) or JWT (for API calls). Workloads consume SVIDs over a local Unix socket — they never see private keys cross the network.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-deep-dive-spiffe-spire-1-9d63604e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    A[Workload] -->|asks for SVID via Workload API| B["SPIRE Agent<br/>per node"]
    B -->|attest workload<br/>UID, k8s labels, etc| B
    B -->|already attested by SPIRE Server| C[SPIRE Server]
    C -->|signs SVID matching<br/>registration entry| B
    B -->|hand SVID to workload| A
    A -->|use SVID for mTLS| D[Other workload]
    D -->|verify SVID against trust bundle| D
```

</details>

## SPIFFE Identity

```text
spiffe://<trust-domain>/<workload-path>
        e.g. spiffe://acme.com/ns/prod/sa/payments-api
```

| Part | Meaning |
|------|---------|
| `trust-domain` | Administrative boundary (org, team, cluster). Trust bundles are scoped here. |
| `workload-path` | Hierarchical, organization-defined. No reserved meaning. Common: `/ns/<namespace>/sa/<service-account>` for k8s. |

Trust domains are equivalent to a CA's authority — workloads in the same trust domain implicitly trust the same root.

## SVID Forms

| Form | Format | Use |
|------|--------|-----|
| **x509-SVID** | x509 cert with SPIFFE ID in URI SAN, plus private key | mTLS — TLS handshake authenticates BOTH sides |
| **JWT-SVID** | JWT with `sub` = SPIFFE ID, signed by trust-domain key | API auth where TLS is terminated upstream (e.g. behind a load balancer or for RPC headers) |

Both are short-lived (typical default: 1 hour for x509, 5 min for JWT) and rotated automatically by SPIRE Agent before expiry.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-deep-dive-spiffe-spire-2-d5c0b314.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    A[x509-SVID] --> B["Cert with SPIFFE ID<br/>in SAN URI"]
    A --> C[Private key]
    A --> D["Trust bundle<br/>chain to SPIRE Server's CA"]
    E[JWT-SVID] --> F["JWT: sub=SPIFFE ID,<br/>aud=target service"]
    E --> G["JWKS to verify<br/>from Workload API"]
```

</details>

## SPIRE Architecture

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-deep-dive-spiffe-spire-3-bcb918e3.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart TB
    SS["SPIRE Server<br/>1+ replicas, central CA"] --> DS["(Datastore<br/>Postgres/MySQL/SQLite)"]
    SS --- KS["KeyManager<br/>disk / AWS KMS / HSM"]
    A1["SPIRE Agent<br/>node 1"] -.attested.-> SS
    A2["SPIRE Agent<br/>node 2"] -.attested.-> SS
    W1[Workload A] -->|Workload API socket| A1
    W2[Workload B] -->|Workload API socket| A1
    W3[Workload C] -->|Workload API socket| A2
```

</details>

| Component | Role |
|-----------|------|
| **SPIRE Server** | Root CA for the trust domain. Holds registration entries (rules: "if X, issue SPIFFE ID Y"). Signs SVIDs. |
| **SPIRE Agent** | Runs on every node (DaemonSet on k8s). Attests itself to Server, then attests local workloads and proxies SVIDs. |
| **Workload API** | gRPC API exposed via a Unix domain socket (`/run/spire/agent.sock`). Workloads call `FetchX509SVID` / `FetchJWTSVID`. |
| **Registration Entries** | Rules in Server's datastore: selectors (k8s label, AWS instance tag, Unix UID) → SPIFFE ID to issue. |

## Two-Stage Attestation

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-deep-dive-spiffe-spire-4-21661bb4.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant N as Node
    participant A as SPIRE Agent
    participant S as SPIRE Server
    participant W as Workload pod
    
    Note over N,S: Stage 1: Node attestation (once at boot)
    A->>N: Read attestation evidence<br/>(AWS IID, k8s PSAT, x509)
    A->>S: Connect with evidence
    S->>S: Verify evidence with NodeAttestor plugin
    S-->>A: Issue Agent SVID
    
    Note over W,A: Stage 2: Workload attestation (per fetch)
    W->>A: gRPC FetchX509SVID via UDS
    A->>A: Get caller PID from socket
    A->>A: WorkloadAttestor plugins:<br/>k8s label, Unix UID, Docker label
    A->>A: Match selectors to registration entries
    A->>S: Request SVID for matched SPIFFE ID
    S-->>A: x509-SVID + key + bundle
    A-->>W: SVID material
```

</details>

The two-stage model means: a compromised workload cannot impersonate another, because the AGENT (not the workload) proves identity using kernel-level data the workload can't forge (PID → cgroup → k8s pod → labels).

## Annotated Registration Entry

```yaml
# Register that any pod in namespace "prod" with SA "payments-api"
# running on a node in the "us-east-1a" trust group gets this SPIFFE ID
spire-server entry create \
  -spiffeID spiffe://acme.com/ns/prod/sa/payments-api \
  -parentID spiffe://acme.com/spire/agent/k8s_psat/prod-cluster/abc123 \
  -selector k8s:ns:prod \
  -selector k8s:sa:payments-api \
  -selector k8s:pod-label:app:payments-api \
  -ttl 3600
```

Selectors are AND'd within an entry. A workload must satisfy ALL selectors for the entry to apply. Multiple entries can apply — workload gets multiple SVIDs.

## mTLS Without Secrets

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-11-zero-trust-mesh-deep-dive-spiffe-spire-5-fa8da4f5.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant A as Service A
    participant SA as SPIRE Agent A
    participant B as Service B
    participant SB as SPIRE Agent B
    
    A->>SA: FetchX509SVID
    SA-->>A: SVID + key + trust bundle
    B->>SB: FetchX509SVID
    SB-->>B: SVID + key + trust bundle
    
    A->>B: TLS ClientHello
    B->>A: ServerHello + cert (B's SVID)
    A->>A: Verify cert against trust bundle<br/>extract SPIFFE ID from SAN
    A->>A: Authorize: is this the SPIFFE ID I expected?
    A->>B: Client cert (A's SVID)
    B->>B: Verify + extract SPIFFE ID + authorize
    A->>B: HTTP/2 traffic
```

</details>

Both sides authenticate AND authorize on SPIFFE ID, not on IP/hostname. Trust bundle is auto-rotated by the agent — if SPIRE Server rotates its CA, agents fetch the new bundle and push to workloads BEFORE old certs expire.

## Integration: Envoy SDS

Envoy fetches SVIDs via the SPIFFE-flavored SDS (Secret Discovery Service). The application code doesn't change — Envoy sidecar terminates and originates mTLS using SPIRE-issued certs. This is how Istio (with `--set values.global.spiffe.enabled`) and Consul Connect can layer on SPIRE.

## Common Interview Questions

> [!IMPORTANT]
> **Q1: What is a SPIFFE ID?**
> A: A URI of the form `spiffe://<trust-domain>/<workload-path>` that uniquely identifies a workload. It's embedded in the URI SAN of x509-SVIDs and the `sub` claim of JWT-SVIDs.
>
> **Q2: x509-SVID vs JWT-SVID — when to use which?**
> A: x509-SVID for mTLS (TCP-level mutual auth between services). JWT-SVID for API auth where TLS is terminated upstream (load balancer) or for RPC headers / cross-cluster requests.
>
> **Q3: How does SPIRE attest a workload running in a pod?**
> A: Two stages. First, the SPIRE Agent on the node attests ITSELF to the SPIRE Server via a NodeAttestor plugin (e.g. k8s PSAT, AWS IID). Then, when a workload calls the Workload API, the agent uses the caller PID to introspect cgroups → pod → labels/SA, and matches against registration entry selectors.
>
> **Q4: Why is mTLS with SPIRE "without secrets"?**
> A: Workloads never see long-lived keys. SVIDs are issued per workload, short-lived (1h default), and rotated automatically. Compromise window is bounded; there's no API key to leak or rotate.
>
> **Q5: What's a trust domain and why does it matter?**
> A: An administrative boundary (e.g. `acme.com` or `prod.acme.com`). Each trust domain has its own root CA. Workloads in the same trust domain implicitly trust each other. Cross-domain trust uses **federation**: each domain publishes its bundle for the other to trust selectively.
>
> **Q6: How does the Workload API prevent workload-to-workload impersonation?**
> A: The agent identifies the caller via the Unix socket peer PID, then introspects kernel-level metadata (cgroups, namespaces) the workload can't forge. The workload doesn't tell the agent who it is — the agent observes.
>
> **Q7: What happens when SPIRE Server's CA needs to rotate?**
> A: SPIRE Server generates a new CA, signs new SVIDs with it, and publishes both old and new in the trust bundle. Agents push the updated bundle to workloads. After all old SVIDs expire, the old CA is removed from the bundle. Zero downtime.
>
> **Q8: How is SPIRE different from a service mesh's mTLS?**
> A: SPIRE is identity infrastructure; service meshes consume identities. Istio/Linkerd have built-in identity (Citadel/identity service) but they're mesh-scoped. SPIRE is mesh-independent, can identify non-mesh workloads (databases, edge functions, lambdas), and supports federation across clouds.

## Sources

- SPIFFE spec: https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE.md
- SVID spec: https://github.com/spiffe/spiffe/blob/main/standards/X509-SVID.md
- SPIRE docs: https://spiffe.io/docs/latest/spire-about/
- Workload API: https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE_Workload_API.md
- SPIRE concepts: https://spiffe.io/docs/latest/spire-about/spire-concepts/
- Envoy + SPIRE: https://spiffe.io/docs/latest/microservices/envoy/
