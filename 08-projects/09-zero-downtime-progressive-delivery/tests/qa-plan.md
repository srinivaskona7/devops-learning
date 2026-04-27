# QA Plan — Project 09: Zero-Downtime Progressive Delivery

**QA Engineer's contract:** Complete this checklist against a live kind cluster. Every row must reach PASS before the project is considered production-ready.

---

## 1. Pre-flight checks

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| P1 | Cluster healthy | `kubectl get nodes` | All nodes `Ready` |
| P2 | Namespace exists | `kubectl get ns progressive` | `Active` |
| P3 | Istio sidecar injected | `kubectl -n progressive get pods -o jsonpath='{..containers[*].name}'` | `istio-proxy` present in every pod |
| P4 | Prometheus scrapes demo-app | `curl -s localhost:9090/api/v1/targets \| jq '.data.activeTargets[] \| select(.labels.app=="demo-app")'` | State `up` for all pods |
| P5 | AnalysisTemplate exists | `kubectl -n progressive get analysistemplate success-rate` | Resource exists |

---

## 2. Canary deploy — happy path

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| C1 | Canary starts at 20% | `kubectl argo rollouts get rollout demo-app-canary -n progressive` | Weight shows 20 |
| C2 | AnalysisRun created | `kubectl -n progressive get analysisruns` | AnalysisRun with status `Running` |
| C3 | Success-rate gate passes | `kubectl -n progressive get analysisrun -o wide` | `Phase: Successful` for each step |
| C4 | Traffic weight advances | Watch rollout: weight increments 20→40→60→80→100 | Each step advances without manual intervention |
| C5 | v2 pods serving traffic | `curl localhost:8080/api \| jq .version` | Returns `"v2"` after promotion |
| C6 | Zero 5xx during deploy | k6 results: `http_req_failed.rate == 0` | PASS in `make verify` |
| C7 | p95 stays under 200ms | k6 results: `p(95) < 200ms` | PASS in `make verify` |
| C8 | Stable pods scale down | After 100% | v1 ReplicaSet scaled to 0 |

---

## 3. Automated rollback — bad canary

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| R1 | Deploy bad v2 | `make bad-deploy` | Rollout patches bad-weight=0.30 |
| R2 | Error rate rises | `curl -s localhost:9090/api/v1/query?query=job:http_requests:success_rate2m \| jq` | Success rate drops below 99% within 1 min |
| R3 | AnalysisRun fails | `kubectl -n progressive get analysisruns` | Phase changes to `Failed` |
| R4 | Rollout auto-aborts | `kubectl argo rollouts get rollout demo-app-canary -n progressive` | Status: `Degraded` → rollback triggered |
| R5 | Traffic returns to stable | Watch VirtualService weights | Weight snaps back to 100/0 |
| R6 | Zero 5xx on stable path | k6 running during rollback: `http_req_failed.rate == 0` | PASS — Istio retry absorbs in-flight requests |
| R7 | v1 pods still healthy | `kubectl -n progressive get pods` | v1 pods `Running` throughout |

---

## 4. Blue-green deploy

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| B1 | Green slot starts | `make bluegreen-v2` | `demo-app-bluegreen` preview service receives 0% traffic |
| B2 | Preview service reachable | `kubectl -n progressive port-forward svc/demo-app-preview 9090:8080` + `curl localhost:9090/api` | Returns v2 response |
| B3 | Pre-promotion analysis | `kubectl -n progressive get analysisruns` | Runs against preview service, passes |
| B4 | Manual promotion | `make promote` | Traffic cuts over instantly (active→v2) |
| B5 | Post-promotion analysis | `kubectl -n progressive get analysisruns` | Runs against active service, passes |
| B6 | Old blue scales down | After 300s (scaleDownDelaySeconds) | v1 ReplicaSet: 0 replicas |
| B7 | Zero 5xx during cutover | k6 running: error rate 0% | PASS in `make verify` |

---

## 5. Flagger canary (Istio mesh-based)

| # | Test | Command | Pass Criteria |
|---|------|---------|---------------|
| F1 | Flagger detects image change | Update Deployment image tag | Canary resource status: `Progressing` |
| F2 | MetricTemplate queries Prometheus | `kubectl -n progressive describe canary demo-app` | MetricTemplate queries return values |
| F3 | 10% → 100% progression | Watch canary | stepWeight=10 increments each minute |
| F4 | Rollback on metric failure | Set bad-weight on canary pods | Flagger sets status `Failed`, reverts Deployment |

---

## 6. Performance baseline

Run `make load-during` against the **stable** v1 service (before any deploy).

| Metric | Baseline | Acceptable | Fail |
|--------|----------|-----------|------|
| RPS | ≥ 2 000 | ≥ 1 500 | < 1 000 |
| p50 | < 30ms | < 50ms | > 100ms |
| p95 | < 80ms | < 200ms | ≥ 200ms |
| p99 | < 150ms | < 500ms | ≥ 500ms |
| Error rate | 0.000% | 0.000% | any > 0 |

---

## 7. Traffic weight validation

Verify that Istio VirtualService weights match the rollout's declared step weight.

| Step | Expected VS Stable | Expected VS Canary |
|------|-------------------|--------------------|
| Start | 100 | 0 |
| Step 1 | 80 | 20 |
| Step 2 | 60 | 40 |
| Step 3 | 40 | 60 |
| Step 4 | 20 | 80 |
| Complete | 0 | 100 (now stable) |

```bash
# Inspect live VS weights:
kubectl -n progressive get virtualservice demo-app-vs \
  -o jsonpath='{.spec.http[0].route[*].weight}'
```

---

## 8. Observability checks

| # | Check | Tool | Pass |
|---|-------|------|------|
| O1 | Prometheus scrapes both canary + stable pods | Prometheus targets page | Both `up` |
| O2 | Recording rules populated | `kubectl exec prometheus -- promtool query instant http://localhost:9090 job:http_requests:success_rate2m` | Returns non-null for both services |
| O3 | Rollout alert fires on bad deploy | Prometheus alerts page | `CanaryHighErrorRate` fires within 1 min |
| O4 | k6 during-deploy test captures version distribution | `tests/k6/results/summary.json` | `v1_requests_total` and `v2_requests_total` both present |

---

## 9. Zero-downtime final gate

```bash
make load-during &   # start k6 in background
make canary-v2       # start deploy
# wait for deploy to complete, then:
make verify
```

**Expected output:**
```
  [1] HTTP error rate
  Measured : 0.0000%
  Target   : 0.0000%
  ✔ PASS  error_rate=0.0000%

  [2] p95 request latency
  Measured : 87.3ms
  Target   : <200ms
  ✔ PASS  p95=87.3ms

  RESULT: PASS — zero dropped requests, p95 within SLO
```

---

## 10. Rollback from any step

| # | Test | Expected |
|---|------|---------|
| Z1 | `make rollback` at step 1 (20%) | Reverts to 100/0, no errors |
| Z2 | `make rollback` at step 3 (60%) | Reverts, k6 shows 0 errors |
| Z3 | `make rollback` at step 4 (80%) | Reverts, k6 shows 0 errors |

All rollback tests must produce `make verify` → PASS.
