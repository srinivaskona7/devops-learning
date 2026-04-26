# 08 - Supply Chain Security

The build and release pipeline is now the highest-leverage attack surface (SolarWinds, Codecov, xz-utils). The defence framework is **SLSA** — Supply-chain Levels for Software Artifacts.

## SLSA Levels

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-1-8ccaed8e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-1-8ccaed8e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-1-8ccaed8e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    L0[L0<br/>no guarantees] --> L1[L1<br/>provenance exists]
    L1 --> L2[L2<br/>hosted, signed provenance]
    L2 --> L3[L3<br/>hardened build,<br/>tamper-resistant]
    L3 --> L4[L4 - retired<br/>two-party review]

    L1 -.requires.-> Prov[provenance.json:<br/>builder, source, deps]
    L2 -.requires.-> Sign[signed by builder identity]
    L3 -.requires.-> Iso[isolated, ephemeral builder<br/>no maintainer access]
```

</details>

</details>

</details>

| Level | Requirement |
|-------|-------------|
| L0 | None |
| L1 | Provenance exists, can be inspected |
| L2 | Hosted build service, signed provenance |
| L3 | Hardened, isolated, ephemeral builder; no admin can tamper |
| L4 | (retired in v1.0) was two-party review + hermetic |

GitHub Actions + the [`slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator) reusable workflow gets you SLSA L3 for free for OSS repos.

## Building blocks

| Concept | What it is |
|---------|-----------|
| **in-toto** | Framework for attestations (statement + predicate + signature) |
| **Provenance** | A signed predicate describing how an artifact was built |
| **SBOM** | What's *inside* the artifact (see `05-image-security/sbom-syft.md`) |
| **VEX** | Whether SBOM CVEs are actually exploitable |
| **Sigstore (cosign + Fulcio + Rekor)** | The signing + transparency log infrastructure |
| **Signed commits** | `git commit -S` with GPG/SSH key, verified by GitHub |

## A signed-and-attested release

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-2-4d28457f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-2-4d28457f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/06-security-08-supply-chain-README-2-4d28457f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant Dev
    participant GH as GitHub
    participant CI as Actions runner
    participant Reg as ghcr.io
    participant Rekor

    Dev->>GH: git push (signed commit)
    GH->>CI: trigger release.yaml
    CI->>CI: build image
    CI->>Reg: docker push
    CI->>CI: syft → SBOM
    CI->>CI: slsa-generator → provenance
    CI->>Rekor: cosign sign + attest (OIDC)
    Rekor-->>CI: log entry UUID
    CI->>Reg: push signature + attestations
    Note over Reg: Image is now verifiable end-to-end
```

</details>

</details>

</details>

## Files
- `github-actions-slsa.yaml` — full pipeline: build, SBOM, sign, SLSA provenance

## Verification at deploy time
- Use **Kyverno `verifyImages`** or **sigstore policy-controller** to enforce provenance + signature at admission
- Pin to the specific workflow identity, not just "any signed image"
