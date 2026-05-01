# Architecture — Security Hardening Lab

## STRIDE Threat Model

The diagram maps every component to its threat category and the defensive control that mitigates it.

```mermaid
flowchart TB
    DEV["Developer<br/>Workstation"] -->|git push SHA-pinned| SCM["Source Control<br/>GitHub/GitLab"]
    SCM -->|webhook trigger| CI["CI Runner<br/>GitHub Actions"]

    subgraph SupplyChain["Supply Chain Layer — SLSA L2"]
        CI -->|docker build --no-cache| BUILD[Image Build]
        BUILD -->|trivy scan --exit-code 1| TRIVYGATE{HIGH/CRIT?}
        TRIVYGATE -->|no vulns| PUSH[Push to Registry]
        TRIVYGATE -->|found| FAIL([Pipeline FAIL])
        PUSH -->|cosign sign keyless| SIGSTORE["Sigstore<br/>Fulcio + Rekor"]
        PUSH -->|syft -o cyclonedx-json| SBOM[SBOM File]
        SBOM -->|cosign attest| REG["(OCI Registry<br/>ghcr.io)"]
    end

    subgraph Cluster["Kubernetes Cluster"]
        subgraph Admission["Admission Control Layer"]
            REG -->|kubectl apply| API["API Server<br/>kube-apiserver"]
            API -->|ValidatingWebhook| KYV[Kyverno Engine]
            KYV --> P1[require-non-root]
            KYV --> P2[require-resource-limits]
            KYV --> P3[deny-privilege-escalation]
            KYV --> P4[require-image-digest]
            KYV --> P5[restrict-hostpath]
            P1 & P2 & P3 & P4 & P5 -->|all pass| SCHED[kube-scheduler]
            P1 & P2 & P3 & P4 & P5 -->|any fail| DENY([Admission Denied])
        end

        subgraph WorkloadLayer["Workload Layer"]
            SCHED --> NODE[Worker Node]
            NODE --> POD["Pod<br/>UID 1000, read-only FS"]
        end

        subgraph SecretsLayer["Secrets Layer"]
            VAULT["(HashiCorp Vault<br/>AppRole Auth)"] -->|lease| ESO["External Secrets<br/>Operator"]
            ESO -->|k8s Secret| POD
        end

        subgraph NetworkLayer["Network Layer"]
            POD -->|NetworkPolicy allow| SVC[ClusterIP Service]
            SVC --> DB[(Database)]
            NP["NetworkPolicy<br/>default-deny-all"] -.->|blocks all else| POD
        end

        subgraph RuntimeLayer["Runtime Detection Layer"]
            POD -->|syscalls via eBPF| FALCO[Falco Agent]
            FALCO -->|alert stream| OUTPUT["Alert Output<br/>stdout / gRPC / Slack"]
        end
    end

    subgraph Audit["Audit Layer"]
        API -->|audit log| AUDITLOG["Audit Log<br/>JSON to S3/GCS"]
        FALCO --> AUDITLOG
        SIGSTORE --> AUDITLOG
    end
```

---

## Defense-in-Depth: 8 Layers

Each layer is independent. An attacker must bypass all of them in sequence to achieve their goal.

```mermaid
flowchart LR
    L1["Layer 1<br/>Source Control<br/>Signed commits, branch protection"] -->
    L2["Layer 2<br/>CI/CD Hardening<br/>Ephemeral runners, OIDC, no static creds"] -->
    L3["Layer 3<br/>Image Hardening<br/>Trivy scan, distroless, non-root"] -->
    L4["Layer 4<br/>Supply Chain Integrity<br/>cosign keyless, SBOM, SLSA L2"] -->
    L5["Layer 5<br/>Admission Control<br/>Kyverno 5 policies + PSA restricted"] -->
    L6["Layer 6<br/>RBAC + Secrets<br/>Least-privilege SA, Vault + ESO"] -->
    L7["Layer 7<br/>Network Isolation<br/>NetworkPolicy default-deny"] -->
    L8["Layer 8<br/>Runtime Detection<br/>Falco eBPF, 5 custom rules"]
```

---

## STRIDE-to-Control Mapping

```mermaid
flowchart LR
    subgraph Threats["STRIDE Threats"]
        S["Spoofing<br/>fake image"]
        T["Tampering<br/>write /etc in container"]
        R["Repudiation<br/>no build provenance"]
        I["Information Disclosure<br/>secret in env var"]
        D["Denial of Service<br/>unbounded CPU"]
        E["Elevation of Privilege<br/>setuid in container"]
    end

    subgraph Controls["Defensive Controls"]
        C1[cosign verify + digest pin]
        C2[Falco write_etc_dir + read-only FS]
        C3[SLSA provenance + Rekor transparency]
        C4[Vault + External Secrets Operator]
        C5[Kyverno resource limits + LimitRange]
        C6[PSA restricted + deny-privilege-escalation]
    end

    S --> C1
    T --> C2
    R --> C3
    I --> C4
    D --> C5
    E --> C6
```

---

## Trust Boundaries

| Boundary | What crosses it | How it is enforced |
|----------|-----------------|-------------------|
| Developer → CI | Source code | Branch protection + required reviews |
| CI → Registry | OCI image | Trivy gate; no direct developer push |
| Registry → Cluster | Container image | cosign signature verification at admission |
| Cluster → Vault | Secret request | mTLS + Kubernetes auth + AppRole |
| Pod → Pod | API calls | NetworkPolicy + Service mesh mTLS (optional) |
| Pod → Kernel | syscalls | Falco eBPF monitor |
| Pod → API Server | K8s API calls | RBAC least-privilege + token auto-mount disabled |

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Keyless cosign over keypair cosign | No private key to rotate, leak, or lose; identity is OIDC-bound to CI run |
| Kyverno over OPA/Gatekeeper | Native Kubernetes API; generates/mutates resources; richer policy DSL |
| PSA + Kyverno (both) | PSA covers built-in baseline; Kyverno adds digest enforcement and custom rules that PSA cannot express |
| External Secrets over Vault Agent | ESO is a Kubernetes-native CRD controller; no sidecar injection required |
| Falco eBPF over kernel module | eBPF is safe to load in production; kernel module requires node reboot on kernel updates |
| CycloneDX over SPDX | Better toolchain support in cosign attest; richer VEX (vulnerability exploitability exchange) integration |
