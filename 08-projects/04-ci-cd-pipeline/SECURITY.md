# Security Model — Project 04: Advanced CI/CD Pipeline

## Threat Model Summary

The CI/CD pipeline is an attack surface. A compromised pipeline can:
- Ship malicious code to production
- Exfiltrate secrets from the runner environment
- Poison the artifact registry with backdoored images
- Bypass security checks by forking workflows

This document describes how Trivy and cosign protect each attack vector.

---

## Defence Layer 1 — Trivy: Image Vulnerability Scanning

### What Trivy scans

Trivy inspects the final OCI image layers for:

| Target | Examples of findings |
|--------|---------------------|
| OS packages (apt/apk/rpm) | OpenSSL CVEs, glibc vulnerabilities |
| Language dependencies | Go modules, pip packages, npm modules |
| Misconfigurations | Dockerfile `USER root`, no `HEALTHCHECK` |
| Secrets | Hardcoded API keys, private keys in image layers |

### Gate policy

```text
Image built
    │
    ├── CRITICAL (fixable) ──────── exit 1 — pipeline blocked
    ├── HIGH (fixable) ──────────── exit 1 — pipeline blocked
    ├── CRITICAL/HIGH (unfixed) ──── exit 0 — SARIF uploaded to GitHub Security
    ├── MEDIUM ───────────────────── exit 0 — SARIF uploaded
    └── LOW / NEGLIGIBLE ─────────── silently ignored
```

The `--ignore-unfixed` flag prevents the pipeline from blocking on CVEs with no available fix — those are tracked in the GitHub Security tab but do not halt shipping.

### Scanning happens BEFORE push

```bash
docker buildx build → [image in registry] → trivy scan → cosign sign → push final tags
```

This order is critical. If trivy ran after push, a vulnerable image would exist in the registry and could be pulled by other consumers before the gate triggered. The workflow uses a temporary `@sha256:digest` reference so trivy scans the exact digest before tags are promoted.

### SBOM output

The `push` job generates a full SBOM in SPDX 2.3 JSON format:

```bash
# Location in CI artifact:
tests/sbom.spdx.json        # GitHub Actions artifact (90-day retention)

# Location attached to image:
cosign download sbom ghcr.io/ORG/IMAGE@DIGEST
```

The SBOM lists every package, version, and license in the image. This enables:
- License compliance audits
- Dependency inventory for incident response
- Cross-referencing against new CVE disclosures after image publication

### Trivy configuration

```yaml
# infra/trivy.yaml (optional override)
severity:
  - CRITICAL
  - HIGH
vuln-type:
  - os
  - library
ignore-unfixed: true
exit-code: 1
```

---

## Defence Layer 2 — Cosign: Keyless Image Signing

### The problem with key-based signing

Traditional image signing requires a private key:
- Stored as a CI secret — leaked if secret is exfiltrated
- Rotated manually — often not rotated at all
- Audited inconsistently — who signed what, when?

### Keyless signing with OIDC

Cosign keyless signing uses the GitHub Actions OIDC token as identity. No long-lived secret exists.

```text
GitHub Issues OIDC Token
        │
        │  Contains: repository, workflow, ref, run_id, sha
        │  Signed by: GitHub's OIDC provider
        │  Expires: ~10 minutes
        │
        ▼
Sigstore Fulcio CA
        │
        │  Verifies the OIDC token
        │  Issues short-lived X.509 certificate
        │  Subject Alternative Name (SAN) = workflow identity
        │
        ▼
cosign sign
        │
        │  Signs: sha256 digest of the image
        │  Using: ephemeral key pair + Fulcio certificate
        │
        ▼
Sigstore Rekor (transparency log)
        │
        │  Records: signature + certificate + digest
        │  Immutable: entries cannot be deleted
        │  Public: anyone can query
```

### What the signature proves

After a successful `cosign sign`:

1. **The image was built by this specific GitHub Actions workflow** — the certificate's SAN encodes `https://github.com/ORG/REPO/.github/workflows/ci.yml@refs/heads/main`
2. **The image has not been tampered with** — any bit change to the image invalidates the signature
3. **The signing happened at a specific time** — Rekor timestamp is verifiable
4. **The chain of custody is auditable** — query `rekor-cli` by digest to see full provenance

### Verification

Anyone (internal auditor, external security researcher, automated policy engine) can verify:

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/YOUR_ORG/YOUR_REPO/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/YOUR_ORG/YOUR_REPO:main
```

Output (truncated):
```json
[
  {
    "critical": {
      "identity": {
        "docker-reference": "ghcr.io/your-org/cicd-demo"
      },
      "image": {
        "docker-manifest-digest": "sha256:a1b2c3..."
      },
      "type": "cosign container image signature"
    },
    "optional": {
      "Bundle": {
        "Payload": {
          "rekorBundle": {
            "LogEntry": {
              "UUID": "abc123...",
              "logID": "c0d23d...",
              "logIndex": 123456789
            }
          }
        }
      },
      "Issuer": "https://token.actions.githubusercontent.com",
      "Subject": "https://github.com/your-org/cicd-demo/.github/workflows/ci.yml@refs/heads/main"
    }
  }
]
```

### Enforcement in cluster (optional extension)

To enforce that only signed images run in your Kubernetes cluster, deploy Sigstore policy-controller:

```bash
helm install policy-controller sigstore/policy-controller \
  --namespace cosign-system \
  --create-namespace

kubectl apply -f - <<EOF
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-signature
spec:
  images:
    - glob: "ghcr.io/YOUR_ORG/**"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: "https://github.com/YOUR_ORG/.*"
EOF
```

Any attempt to deploy an unsigned image to the cluster will be rejected by the admission webhook.

---

## Secrets Management

| Secret | Scope | Rotation |
|--------|-------|----------|
| `GITHUB_TOKEN` | Ephemeral, per-job | Auto-rotated by GitHub |
| `PREVIEW_KUBECONFIG` | Repo secret | Rotate every 90 days; use short-lived tokens |
| cosign keyless | No secret — OIDC token | No rotation needed |

**Never store:**
- Docker Hub PATs in CI (use GHCR + `GITHUB_TOKEN`)
- Long-lived kubeconfig admin tokens (use service accounts with least privilege)
- Cosign private keys (use keyless)

---

## OIDC Permission Minimization

```yaml
# Wrong: too broad
permissions: write-all

# Correct: per-job minimum
jobs:
  build:
    permissions:
      contents: read
      packages: write
  sign:
    permissions:
      id-token: write   # OIDC token only
      packages: write
  scan:
    permissions:
      contents: read
      security-events: write  # SARIF upload only
```

The `id-token: write` permission must be scoped to the `sign` job only. Any job with this permission can request an OIDC token and impersonate the workflow identity.

---

## Audit Trail

Every pipeline run produces:

| Artifact | Location | Retention |
|----------|----------|-----------|
| Trivy SARIF | GitHub Security tab | Until dismissed |
| Coverage report | GitHub Actions artifacts | 7 days |
| SBOM (SPDX JSON) | GitHub Actions artifacts + GHCR image | 90 days |
| Cosign signature | GHCR (`.sig` artifact) | Permanent |
| Rekor log entry | `rekor.sigstore.dev` | Permanent, public |
| Build provenance | GHCR (SLSA provenance attestation) | Permanent |

An incident responder can answer "what was in the image deployed at 14:32 UTC on 2026-03-15" by:

```bash
# 1. Find the digest from the deployment event / git tag
DIGEST="sha256:a1b2c3..."

# 2. Download the SBOM
cosign download sbom ghcr.io/ORG/IMAGE@${DIGEST}

# 3. Verify the signature and get the Rekor entry
cosign verify --certificate-oidc-issuer ... ghcr.io/ORG/IMAGE@${DIGEST}

# 4. Get the Rekor log entry
rekor-cli get --uuid <UUID from cosign verify output>
```

This audit takes under 2 minutes — compared to hours of digging through CI logs without this setup.
