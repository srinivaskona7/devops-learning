# Architecture Deep-Dive — Project 04 CI/CD Pipeline

## PR Flow (pull_request event)

```mermaid
flowchart TD
  subgraph Trigger
    DEV[Developer push] --> GH[GitHub PR event]
  end

  subgraph Parallel Gate
    GH --> LINT[Job: lint\ngolangci-lint run ./...]
    GH --> TEST[Job: test\ngo test -race ./...]
  end

  subgraph Build
    LINT --> BUILD[Job: build-multi-arch\ndocker buildx\nlinux/amd64 + linux/arm64]
    TEST --> BUILD
    BUILD --> CACHE[(GHA Cache\ntype=gha,mode=max)]
  end

  subgraph Security
    BUILD --> SCAN[Job: trivy-scan\nSARIF → GitHub Security tab]
    SCAN -->|CRITICAL found| FAIL[Pipeline BLOCKED]
    SCAN -->|clean| SIGN[Job: cosign-sign\nkeyless OIDC → Fulcio → Rekor]
  end

  subgraph Publish
    SIGN --> PUSH[Job: push-ghcr\nghcr.io/org/app:pr-42]
  end

  subgraph Preview
    PUSH --> DEPLOY[Job: deploy-preview\nkubectl apply -n pr-42]
    DEPLOY --> COMMENT[gh pr comment\nPreview URL posted]
  end
```

---

## Main Branch Flow (push to main)

```mermaid
flowchart TD
  subgraph Trigger
    MERGE[Merge to main] --> EVENT[push event on main]
  end

  subgraph Parallel Gate
    EVENT --> LINT[lint]
    EVENT --> TEST[test -race]
  end

  subgraph Build + Secure
    LINT --> BUILD[build-multi-arch\n:main + :sha]
    TEST --> BUILD
    BUILD --> SCAN[trivy-scan]
    SCAN --> SIGN[cosign-sign keyless]
    SIGN --> PUSH[push-ghcr\n:main + :sha]
  end

  subgraph Integration Test
    PUSH --> KIND[kind create cluster\nci-$run_id]
    KIND --> KDEPLOY[kubectl apply]
    KDEPLOY --> K6[k6 run smoke.js\n30 VUs 30s]
    K6 --> KDELETE[kind delete cluster]
  end

  subgraph Artifact
    KDELETE --> SBOM[trivy sbom\noutput: sbom.spdx.json]
    SBOM --> ATTACH[cosign attach sbom]
  end
```

---

## Release Flow (git tag v*)

```mermaid
flowchart LR
  TAG[git tag v1.2.3\ngit push --tags] --> RTAG[on: push tags v*]

  RTAG --> RBUILD[build-multi-arch\n:v1.2.3 + :latest]
  RBUILD --> RSCAN[trivy-scan\nfail on CRITICAL]
  RSCAN --> RSIGN[cosign-sign keyless]
  RSIGN --> RPUSH[push-ghcr\n:v1.2.3 + :1.2 + :1 + :latest]
  RPUSH --> RSBOM[trivy sbom → cosign attach]
  RSBOM --> RNOTES[gh release create\nauto release notes\nattach sbom.spdx.json]
```

---

## Fan-Out Stage Details

```mermaid
gantt
  title Pipeline wall-clock time (approximate)
  dateFormat  s
  axisFormat  %Ss

  section Parallel
  lint          :0, 18s
  test          :0, 12s

  section Sequential (starts after max of above)
  build amd64   :18, 30s
  build arm64   :18, 42s
  trivy-scan    :60, 23s
  cosign-sign   :83, 8s
  push-ghcr     :91, 14s
  deploy-preview:105, 31s
```

Total: ~2m 16s vs ~4m 2s sequential. Fan-out saves ~1m 46s on every push.

---

## Keyless Signing Detail

```mermaid
sequenceDiagram
  participant Runner as GHA Runner
  participant GH as GitHub OIDC Provider
  participant Fulcio as Sigstore Fulcio CA
  participant Rekor as Sigstore Rekor Log
  participant GHCR as GHCR Registry

  Runner->>GH: Request OIDC token (id-token: write permission)
  GH-->>Runner: JWT (claims: repo, workflow, ref, run_id)
  Runner->>Fulcio: POST /api/v1/signingCert {jwt, public_key}
  Fulcio-->>Runner: X.509 cert (valid 10 min, SAN = workflow identity)
  Runner->>Runner: cosign sign --identity-token ... image@digest
  Runner->>Rekor: POST /api/v1/log/entries {sig, cert, digest}
  Rekor-->>Runner: log entry UUID + inclusion proof
  Runner->>GHCR: push .sig OCI artifact (attached to image digest)
```

---

## Preview Environment Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Open: PR opened / PR synchronized
  Open --> Deploying: deploy-preview job starts
  Deploying --> Live: kubectl apply -n pr-42 succeeds
  Live --> Live: PR push → redeploy same namespace
  Live --> Cleanup: PR closed / merged
  Cleanup --> [*]: kubectl delete namespace pr-42
```

---

## Image Tag Strategy

| Event | Tags pushed | Example |
|-------|------------|---------|
| PR push | `:pr-<number>` | `app:pr-42` |
| Main push | `:main`, `:sha-<short>` | `app:main`, `app:sha-a1b2c3` |
| Semver tag | `:v<major>.<minor>.<patch>`, `:v<major>.<minor>`, `:v<major>`, `:latest` | `app:v1.2.3`, `app:v1.2`, `app:v1`, `app:latest` |

This strategy is identical to the Docker Hub official image tagging convention and is understood natively by tools like Renovate and Dependabot.

---

## Cache Architecture

```bash
GHA Cache store (10 GB limit per repo)
├── go-<os>-<go.sum hash>          ← Go modules + build cache
│   ├── ~/go/pkg/mod/
│   └── ~/.cache/go-build/
├── main-buildkit                  ← BuildKit layers for main branch
│   └── all intermediate layers (mode=max)
├── feature-X-buildkit             ← BuildKit layers for branch X
│   └── differential from main (only changed layers)
└── pr-42-buildkit                 ← BuildKit layers for PR 42
    └── restored from main first, then PR-specific
```

**Cache invalidation rules:**
- `go.sum` changes → Go module cache misses, full `go mod download`
- `go.mod` changes without `go.sum` → cache restore-key fallback (`os-go-`) fetches nearest match
- `FROM` base image changes in Dockerfile → all layers above it rebuild, rest are cached
- `COPY go.mod go.sum` layer change → only dependency install layer rebuilds

---

## Security Gate Policy

```text
Image build output
    │
    ├── CRITICAL CVEs (fixable) ────── BLOCK pipeline, fail job exit 1
    ├── HIGH CVEs (fixable) ─────────── BLOCK pipeline, fail job exit 1
    ├── CRITICAL/HIGH (unfixed) ─────── WARN, upload SARIF, continue
    ├── MEDIUM CVEs ─────────────────── WARN, upload SARIF, continue
    └── LOW / NEGLIGIBLE ────────────── ignored (not reported)
```

SARIF uploads to GitHub Security → Code Scanning → appears in PR checks. Security engineers review MEDIUM/unfixed items on a weekly cadence, not per-commit.
