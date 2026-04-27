# Platform Acceptance Test Plan

**Project:** Platform Engineering End-to-End Capstone
**Owner:** Platform Team QA
**Last updated:** 2026-04-27
**Purpose:** Every capability slice has an automated acceptance test. Run this matrix after any platform change.

---

## How to run

```bash
# Run all automated tests (skips manual tests)
make audit            # security audit
make perf-drill       # performance tests
make chaos-drill      # chaos tests (requires load running)

# Individual test groups:
kubectl get policyreport --all-namespaces    # Policy tests
argocd app list                             # GitOps tests
istioctl authn tls-check --all-namespaces   # mTLS tests
```

---

## Platform bootstrap tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| B01 | All platform pods Running | `kubectl get pods --all-namespaces` | 0 pods in Error/CrashLoopBackOff | Auto |
| B02 | Argo CD app-of-apps Synced | `argocd app get platform-root` | Status: Synced, Health: Healthy | Auto |
| B03 | All 5 child apps Synced | `argocd app list` | All 5 show Synced/Healthy | Auto |
| B04 | Istio mesh running | `istioctl check-inject --all-namespaces` | 0 warnings | Auto |
| B05 | Vault unsealed | `vault status` | Sealed: false, Active: true | Auto |
| B06 | ESO controller running | `kubectl get pods -n external-secrets` | All Running | Auto |
| B07 | Kyverno webhook Active | `kubectl get validatingwebhookconfigurations` | kyverno webhook present | Auto |
| B08 | Prometheus scraping | Prometheus targets UI | 0 targets Down | Manual |
| B09 | Grafana data sources | Grafana UI → Data sources | All sources show green | Manual |
| B10 | Backstage catalog loading | `curl http://backstage:7007/api/catalog/entities` | 200 OK, entities present | Auto |

---

## Delivery slice tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| D01 | Canary deploy creates two ReplicaSets | `kubectl get replicasets -n payment` | 2 RS (stable + canary) | Auto |
| D02 | Istio traffic split at 10/90 | `istioctl proxy-config route` | canary weight=10, stable weight=90 | Auto |
| D03 | SLO gate queries Prometheus | `kubectl get analysisrun -n payment` | AnalysisRun created during canary | Auto |
| D04 | Canary auto-promotes on SLO pass | Inject no errors, wait 25m | All traffic shifts to canary | Auto |
| D05 | Canary auto-rollbacks on SLO fail | Inject 5% errors, watch rollout | Status: Degraded → Rollback | Auto |
| D06 | Manual rollback works | `kubectl argo rollouts abort` | Stable restored within 60s | Manual |
| D07 | Revision history maintained | `kubectl argo rollouts history` | Last 5 revisions visible | Auto |
| D08 | Zero dropped requests during canary | Run k6 during canary | 0 errors in k6 output | Auto |

---

## Observability slice tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| O01 | Prometheus scrapes payment-service | Prometheus /targets | payment-service target Up | Auto |
| O02 | RED metrics present | PromQL `http_requests_total{job="payment-service"}` | > 0 after load | Auto |
| O03 | p95 recording rule evaluates | PromQL `job:http_request_duration_p95:5m` | Non-null value | Auto |
| O04 | SLO availability rule evaluates | PromQL `slo:availability:ratio_30d` | Between 0 and 1 | Auto |
| O05 | Traces visible in Tempo | Send request, check Tempo | Trace with spans visible | Manual |
| O06 | Trace ID in log lines | Check Loki log output | `trace_id` field present | Auto |
| O07 | Loki receives logs | Loki `/ready` + query | 200 OK, logs returned | Auto |
| O08 | Grafana dashboard loads | `curl grafana/d/platform-payment-service` | 200 OK | Auto |
| O09 | Alert fires on error rate spike | Inject errors > 0.5% for 2m | Alert fires in Alertmanager | Auto |
| O10 | Error budget burn alert fires | Inject sustained errors | SLOGoldFastBurn alert fires | Auto |
| O11 | Deploy annotation visible in Grafana | Deploy new image | Blue annotation line in dashboard | Manual |
| O12 | Log → Trace link works in Grafana | Find log line in Loki | Click trace_id → opens Tempo | Manual |

---

## Security slice tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| S01 | Kyverno blocks missing labels | Apply pod without `app` label | Admission denied | Auto |
| S02 | Kyverno blocks root container | Apply pod with `runAsUser: 0` | Admission denied | Auto |
| S03 | Kyverno blocks missing limits | Apply container without CPU limit | Admission denied | Auto |
| S04 | Kyverno blocks unsigned image | Apply pod with unsigned image | Admission denied by verifyImages | Auto |
| S05 | Kyverno blocks missing probes | Apply Deployment without readinessProbe | Admission denied | Auto |
| S06 | mTLS enforced between pods | `istioctl authn tls-check payment` | STRICT everywhere | Auto |
| S07 | Plain HTTP rejected between pods | `kubectl exec` + curl HTTP between pods | Connection refused / TLS error | Manual |
| S08 | ExternalSecret syncs from Vault | Check `kubectl get externalsecret` | Status: SecretSynced | Auto |
| S09 | Secret rotation triggers pod restart | Rotate secret in Vault | Pod restarts with new env vars within 1h | Auto |
| S10 | Vault unseals after pod restart | Restart vault pod | Vault unseals and becomes Active | Manual |
| S11 | Cosign signature verification passes | `cosign verify <signed-image>` | Verification successful | Auto |
| S12 | Cosign rejects unsigned image | `cosign verify <unsigned-image>` | Error: no matching signatures | Auto |
| S13 | AuthorizationPolicy denies unauthorized namespace | Call payment-service from unauthorized ns | 403 RBAC denied | Auto |
| S14 | Kyverno generates NetworkPolicy | Create new namespace | Default deny NetworkPolicy created | Auto |

**How to run security tests S01–S05 (Kyverno enforcement):**

```bash
# S01: Missing labels
kubectl apply --dry-run=server - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-labels-test
  namespace: payment
spec:
  containers:
    - name: test
      image: nginx
EOF
# Expected: "resource violations found" or admission webhook error

# S02: Root user
kubectl apply --dry-run=server - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: root-test
  namespace: payment
  labels:
    app: test
    version: "1.0"
    team: payments
spec:
  containers:
    - name: test
      image: nginx
      securityContext:
        runAsUser: 0
EOF
# Expected: admission denied
```

---

## Reliability slice tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| R01 | Pod kill recovery < 30s | `chaos-drill` + stopwatch | p95 recovers within 30s | Auto |
| R02 | Network delay: error rate 0% | 100ms delay experiment | Error rate stays 0% | Auto |
| R03 | CPU stress: HPA scales within 60s | stress experiment | Replica count increases | Auto |
| R04 | HPA scale-down after chaos ends | Post-stress observation | Replicas return to min within 5m | Auto |
| R05 | k6 smoke: p95 < 50ms | k6 smoke (10 VUs, 1m) | p95 < 50ms | Auto |
| R06 | k6 load: p95 < 150ms (gold) | k6 load (500 VUs, 5m) | p95 < 150ms, errors 0% | Auto |
| R07 | k6 stress: error rate < 0.1% | k6 stress (1000 VUs, 10m) | Error rate < 0.1% | Auto |
| R08 | SLO canary gate blocks bad deploy | Deploy + inject errors | Rollout aborts, rollback completes | Auto |
| R09 | SLO recording rules consistent | Compare 5m and 30d rules | Values within expected range | Auto |
| R10 | Zero downtime during canary | k6 running during canary step | 0 dropped requests | Auto |

---

## Developer experience tests

| ID | Test | Tool | Expected result | Manual? |
|----|------|------|-----------------|---------|
| X01 | Backstage template renders | `make onboard-demo` | New service live in Argo CD | Auto |
| X02 | Scaffold service has all required labels | `kubectl get pods -n <new-ns>` | All 3 labels present | Auto |
| X03 | Scaffold service has probes | `kubectl describe pod` | ReadinessProbe + LivenessProbe configured | Auto |
| X04 | Scaffold service passes all Kyverno policies | `kubectl get policyreport -n <new-ns>` | 0 violations | Auto |
| X05 | Scaffold service metrics scraped | Prometheus targets | New service target Up | Auto |
| X06 | Grafana dashboard provisioned | `curl grafana/d/platform-<service>` | 200 OK | Auto |
| X07 | Backstage catalog shows new service | Backstage UI | Service entry visible | Manual |
| X08 | Vault path seeded for new service | `vault kv get secret/<service>` | Placeholder values present | Auto |
| X09 | ExternalSecret syncs for new service | `kubectl get externalsecret -n <ns>` | SecretSynced | Auto |
| X10 | `make help` shows all targets | `make help` | All targets listed with descriptions | Auto |

---

## Test execution matrix

Run this matrix in order. Failures in group B (bootstrap) block all other groups.

```
B (Bootstrap) → must pass 100% before proceeding
D (Delivery)  → run after B
O (Observability) → run after B
S (Security)  → run after B
R (Reliability) → run after D + O
X (DX)        → run after all
```

**Automated test script:**

```bash
#!/bin/bash
set -e

echo "=== Platform Acceptance Tests ==="
FAILURES=0

run_test() {
  local ID=$1 DESC=$2 CMD=$3
  printf "%-5s %-60s" "$ID" "$DESC"
  if eval "$CMD" > /dev/null 2>&1; then
    echo "PASS"
  else
    echo "FAIL"
    FAILURES=$((FAILURES + 1))
  fi
}

# Bootstrap tests
run_test "B01" "All pods not in error state" \
  "! kubectl get pods --all-namespaces --no-headers | grep -E 'Error|CrashLoop'"

run_test "B05" "Vault is unsealed" \
  "kubectl exec -n vault vault-0 -- vault status | grep 'Sealed.*false'"

run_test "B07" "Kyverno webhook exists" \
  "kubectl get validatingwebhookconfigurations | grep kyverno"

# Security tests
run_test "S01" "Kyverno blocks missing labels" \
  "! kubectl apply --dry-run=server -f tests/fixtures/pod-no-labels.yaml 2>/dev/null"

run_test "S02" "Kyverno blocks root user" \
  "! kubectl apply --dry-run=server -f tests/fixtures/pod-root-user.yaml 2>/dev/null"

echo ""
echo "=== Results: $FAILURES failures ==="
exit $FAILURES
```

---

## Performance acceptance criteria

| Scenario | p50 | p95 | p99 | Error rate | Concurrency |
|----------|-----|-----|-----|------------|-------------|
| Smoke | &lt;20ms | &lt;50ms | &lt;100ms | 0% | 10 VUs, 1m |
| Load | &lt;50ms | &lt;150ms | &lt;250ms | 0% | 500 VUs, 5m |
| Stress | &lt;80ms | &lt;200ms | &lt;400ms | &lt;0.1% | 1000 VUs, 10m |
| Soak | &lt;50ms | &lt;150ms | &lt;250ms | 0% | 200 VUs, 60m |
| Chaos+Load | &lt;100ms | &lt;300ms | &lt;500ms | &lt;0.1% | 500 VUs + chaos |
