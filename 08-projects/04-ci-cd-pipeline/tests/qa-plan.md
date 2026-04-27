# QA Plan — Project 04: Advanced CI/CD Pipeline

## Test Pyramid Distribution

```
          /\
         /  \
        / E2E \       10%  — 4 scenarios
       /--------\
      /Integration\   20%  — 8 scenarios
     /--------------\
    /   Unit Tests   \  70%  — 16 scenarios
   /------------------\
```

Total: 28 test scenarios across 6 phases.

## Gate Policies

| Severity | Policy |
|----------|--------|
| Unit test failure | **BLOCK** — pipeline does not proceed to build |
| Race condition detected | **BLOCK** — go test -race fails |
| CRITICAL CVE (fixable) | **BLOCK** — trivy exits 1 |
| HIGH CVE (fixable) | **BLOCK** — trivy exits 1 |
| CRITICAL/HIGH CVE (unfixed) | **TRACK** — SARIF uploaded, pipeline continues |
| Cosign verification failure | **BLOCK** — deploy cannot proceed without valid signature |
| k6 p95 > 200ms | **BLOCK** — integration test threshold violation |
| k6 error rate > 1% | **BLOCK** — integration test threshold violation |

---

## Phase 1 — Unit Tests (70%)

**Tool:** `go test -race -v ./...`
**Run:** `make test`
**Pass criteria:** all assertions green, race detector reports no issues

| # | Test | File | What it proves |
|---|------|------|----------------|
| 1 | `TestHealthzHandler` | `app/main_test.go` | `/healthz` returns 200 + `{"status":"ok"}` |
| 2 | `TestReadyHandler` | `app/main_test.go` | `/ready` returns 200 + `{"status":"ready"}` |
| 3 | `TestHelloHandler_status` | `app/main_test.go` | `/api/hello` returns 200 |
| 4 | `TestHelloHandler_contentType` | `app/main_test.go` | `Content-Type: application/json` header set |
| 5 | `TestHelloHandler_message` | `app/main_test.go` | `message` field is non-empty string |
| 6 | `TestHelloHandler_hostname` | `app/main_test.go` | `hostname` field is non-empty string |
| 7 | `TestHelloHandler_timestamp` | `app/main_test.go` | `timestamp` field is non-zero |
| 8 | `TestNewMux_healthz` | `app/main_test.go` | `/healthz` route registered |
| 9 | `TestNewMux_ready` | `app/main_test.go` | `/ready` route registered |
| 10 | `TestNewMux_hello` | `app/main_test.go` | `/api/hello` route registered |
| 11 | Race: concurrent `/healthz` | `go test -race` | no data race on handler |
| 12 | Race: concurrent `/api/hello` | `go test -race` | no data race on hostname lookup |

**How to verify:**
```bash
make test
# Expected output:
# --- PASS: TestHealthzHandler (0.00s)
# --- PASS: TestReadyHandler (0.00s)
# --- PASS: TestHelloHandler (0.00s)
# --- PASS: TestNewMux_RegistersRoutes (0.00s)
# PASS
# coverage: 87.5% of statements
```

---

## Phase 2 — Integration Tests (20%)

**Tool:** `kind` + `kubectl` + `k6`
**Run:** `make test-integration`
**Pass criteria:** all HTTP checks pass, k6 thresholds not violated

| # | Test | Tool | Pass criteria |
|---|------|------|---------------|
| 13 | Container starts in kind cluster | kubectl rollout status | rollout complete within 60s |
| 14 | `/healthz` responds in kind | curl | HTTP 200, body `{"status":"ok"}` |
| 15 | `/ready` responds in kind | curl | HTTP 200, body `{"status":"ready"}` |
| 16 | `/api/hello` responds in kind | curl | HTTP 200, valid JSON with message+hostname+timestamp |
| 17 | k6: error rate < 1% | k6 threshold | rate < 0.01 |
| 18 | k6: healthz p95 < 50ms | k6 threshold | p(95) < 50 |
| 19 | k6: hello p95 < 200ms | k6 threshold | p(95) < 200 |
| 20 | Readiness probe passes | kubectl get pod | `Ready: True` within 30s |

**How to verify:**
```bash
make test-integration
# Expected output:
# ✓ healthz status 200
# ✓ hello status 200
# ✓ error_rate.........: 0.00%
# ✓ http_req_duration{name:hello}: p(95)=12.4ms
```

---

## Phase 3 — Security Gate Tests (pipeline-level)

**Tool:** Trivy + cosign
**Run:** `make scan` / `make sign-local`
**Pass criteria:** scan exits 0 on clean image; exits 1 on known-bad image

| # | Test | Tool | Pass criteria |
|---|------|------|---------------|
| 21 | Clean image passes scan | trivy | exit 0, 0 CRITICAL/HIGH fixable CVEs |
| 22 | Vulnerable image blocks pipeline | trivy | exit 1, CRITICAL CVE logged |
| 23 | Cosign signature attaches to digest | cosign sign | .sig artifact in GHCR |
| 24 | Cosign verify passes after signing | cosign verify | JSON output with Rekor entry |

**How to test the scan gate manually:**
```bash
# Temporarily add to app/Dockerfile before the COPY line:
# RUN apk add --no-cache openssl=1.0.2u-r0
make build-local
make scan
# Expected: exit code 1, CRITICAL CVE output
```

**How to verify signing locally:**
```bash
make sign-local
# Then verify:
cosign verify --key cosign.pub ghcr.io/YOUR_ORG/cicd-demo:dev
```

---

## Phase 4 — E2E Tests (10%)

**Tool:** `curl` + `gh` CLI (simulates full PR lifecycle)
**Run:** manually or in staging environment
**Pass criteria:** preview URL live within 3 minutes of PR push; deleted within 1 minute of PR close

| # | Test | Steps | Pass criteria |
|---|------|-------|---------------|
| 25 | PR preview URL appears as comment | Push branch → open PR → wait 3 min | PR comment contains `https://pr-*.preview.example.com` |
| 26 | Preview URL serves the app | `curl https://pr-42.preview.example.com/healthz` | HTTP 200 |
| 27 | Preview updates on new push | Push commit to PR branch → wait 2 min | PR comment updated, new image tag visible |
| 28 | Preview deleted on PR close | Close PR → wait 1 min | `kubectl get namespace pr-42` returns NotFound |

**How to run E2E manually:**
```bash
# Create a test branch and PR
git checkout -b test/e2e-check
echo "# test" >> app/main.go
git commit -am "test: trigger preview"
git push origin test/e2e-check
gh pr create --title "E2E test PR" --body "Testing preview environment"

# Monitor the Actions run
gh run watch

# Check the PR comment
gh pr view --comments | grep "Preview"

# Verify the preview URL (replace 42 with actual PR number)
PR=$(gh pr view --json number -q .number)
curl -sf "https://pr-${PR}.preview.example.com/healthz"

# Close the PR
gh pr close ${PR}

# Verify cleanup
sleep 60
kubectl get namespace "pr-${PR}" 2>&1 | grep "not found"
```

---

## Phase 5 — Cache Efficiency Tests

**Tool:** GitHub Actions logs (manual review)
**Run:** two consecutive pushes, compare build times
**Pass criteria:** second build < 60s (vs. ~90s cold)

| # | Test | How to check | Pass criteria |
|---|------|-------------|---------------|
| 29 | Go module cache hit on identical go.sum | Actions log: "Cache restored" | Cache hit, `go mod download` skipped |
| 30 | BuildKit layer cache hit on changed main.go | Actions log: layer digests | Only app layer rebuilds, all deps layers cached |

**How to verify:**
```bash
# First push (cold cache): note build time in GitHub Actions log
git commit --allow-empty -m "test: cold cache"
git push

# Second push (warm cache): note build time
git commit --allow-empty -m "test: warm cache"
git push

# Compare "build-multi-arch" job times in GitHub Actions UI
# Warm cache should be 40-60% faster
```

---

## Phase 6 — Release Flow Tests

| # | Test | How to check | Pass criteria |
|---|------|-------------|---------------|
| 31 | Semver tag triggers release workflow | `git tag v0.1.0 && git push --tags` | `release.yml` starts |
| 32 | Image tagged with full semver | GHCR packages page | `:v0.1.0`, `:v0.1`, `:v0`, `:latest` all exist |
| 33 | GitHub Release created with release notes | GitHub Releases page | Release exists with changelog and sbom.spdx.json attachment |
| 34 | SBOM attached to release | `cosign download sbom ghcr.io/org/app:v0.1.0` | SPDX JSON returned |

---

## Regression Checklist (run before any major change)

Before merging any change to `.github/workflows/ci.yml`:

- [ ] `make lint` passes
- [ ] `make test` passes with race detector
- [ ] `make build-local` produces an image
- [ ] `make scan` exits 0 on the built image
- [ ] `make test-integration` completes without k6 threshold violations
- [ ] A test PR shows the preview URL comment within 3 minutes
- [ ] Closing the test PR removes the namespace within 1 minute
- [ ] A test semver tag produces a GitHub Release with attached SBOM

---

## Performance Baseline

| Metric | Target | Alert threshold |
|--------|--------|----------------|
| `lint` job time | < 30s | > 60s |
| `test` job time | < 20s | > 45s |
| `build-multi-arch` (warm) | < 60s | > 120s |
| `build-multi-arch` (cold) | < 120s | > 240s |
| `trivy-scan` | < 30s | > 90s |
| `cosign-sign` | < 15s | > 30s |
| Total pipeline (PR) | < 3.5 min | > 7 min |
| k6 hello p95 | < 50ms | > 200ms |
| k6 error rate | 0% | > 0.1% |
