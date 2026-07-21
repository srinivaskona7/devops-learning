# QA Plan — Project 03 · GitOps with Argo CD

> **Audience:** QA engineers and platform SREs who need to validate the GitOps setup from scratch.
> **Goal:** Confirm that Argo CD enforces Git as the single source of truth — every test verifies one GitOps guarantee.

---

## Pre-conditions

| Item | Command | Expected |
|------|---------|---------|
| kind cluster running | `kubectl get nodes` | 3 nodes Ready |
| Argo CD installed | `kubectl -n argocd get deploy argocd-server` | 1/1 Available |
| All apps Synced+Healthy | `kubectl -n argocd get applications` | 4 apps green |
| k6 installed | `k6 version` | ≥ 0.52 |
| argocd CLI installed | `argocd version --client` | ≥ 2.12 |

---

## Phase 1 — Bootstrap validation

**Objective:** Confirm Argo CD is correctly installed and configured.

### TC-1.1 — UI accessible

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
curl -sk https://localhost:8080/healthz
```

Pass: returns `{"status":"ok"}`

### TC-1.2 — All 4 Applications Synced and Healthy

```bash
kubectl -n argocd get applications \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'
```

Pass: every row shows `Synced` + `Healthy`

### TC-1.3 — Each overlay namespace has correct replica count

```bash
kubectl get deploy url-shortener-api -n api-dev     -o jsonpath='{.spec.replicas}'; echo
kubectl get deploy url-shortener-api -n api-staging -o jsonpath='{.spec.replicas}'; echo
kubectl get deploy url-shortener-api -n api-prod    -o jsonpath='{.spec.replicas}'; echo
```

Pass: `1` · `2` · `3`

### TC-1.4 — PDB exists in api-prod with correct spec

```bash
kubectl -n api-prod get pdb url-shortener-api-pdb \
  -o jsonpath='{.spec.minAvailable}'; echo
```

Pass: `2`

### TC-1.5 — Resource limits set on prod pods

```bash
kubectl -n api-prod get deploy url-shortener-api \
  -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .
```

Pass: `limits.cpu` = `500m`, `limits.memory` = `256Mi`

---

## Phase 2 — Drift detection and auto-heal

**Objective:** Confirm that Argo CD detects and reverses manual cluster mutations.

### TC-2.1 — Scale drift detected within 3 minutes

```bash
# Step 1: introduce drift
kubectl -n api-prod scale deploy url-shortener-api --replicas=0
DRIFT_TIME=$(date +%s)

# Step 2: poll for sync status
while true; do
  STATUS=$(kubectl -n argocd get app api-prod \
    -o jsonpath='{.status.sync.status}')
  echo "[$(date +%T)] sync.status=$STATUS"
  [[ "$STATUS" == "OutOfSync" ]] && break
  sleep 5
done

DETECT_TIME=$(date +%s)
echo "Drift detected in: $((DETECT_TIME - DRIFT_TIME))s"
```

Pass: OutOfSync detected within 180 seconds

### TC-2.2 — Auto-heal restores 3 replicas

```bash
# Continuing from TC-2.1 — wait for selfHeal to trigger
while true; do
  READY=$(kubectl -n api-prod get deploy url-shortener-api \
    -o jsonpath='{.status.readyReplicas}')
  echo "[$(date +%T)] readyReplicas=$READY"
  [[ "$READY" == "3" ]] && break
  sleep 5
done

HEAL_TIME=$(date +%s)
echo "Total heal time: $((HEAL_TIME - DRIFT_TIME))s"
```

Pass: 3 ready replicas restored; heal time ≤ 180 seconds

### TC-2.3 — ConfigMap mutation reverted

```bash
# Inject a bad value
kubectl -n api-prod patch cm url-shortener-config \
  --patch '{"data":{"LOG_LEVEL":"INJECTED_DRIFT"}}'

# Wait for Argo CD sync
sleep 90

# Verify revert
kubectl -n api-prod get cm url-shortener-config \
  -o jsonpath='{.data.LOG_LEVEL}'; echo
```

Pass: `warn` (original prod value restored, not `INJECTED_DRIFT`)

### TC-2.4 — Automated drift-and-heal script

```bash
bash tests/e2e/drift-and-heal.sh api-prod url-shortener-api
```

Pass: script exits 0 and prints `PASS: heal_time=<N>s (≤ 180s)`

---

## Phase 3 — Sync convergence time (PR→live SLA)

**Objective:** Confirm that a git commit deploys within the 3-minute SLA.

### TC-3.1 — Staging image tag bump converges within 3 min

```bash
PUSH_TIME=$(date +%s)

# Bump tag in staging overlay and push
CURRENT=$(grep newTag k8s/overlays/staging/kustomization.yaml | awk '{print $2}' | tr -d '"')
sed -i '' "s/newTag: \"${CURRENT}\"/newTag: \"${CURRENT}-test\"/" \
  k8s/overlays/staging/kustomization.yaml
git add k8s/overlays/staging/kustomization.yaml
git commit -m "qa: sync convergence test"
git push origin main

# Poll until api-staging shows new image
while true; do
  IMG=$(kubectl -n api-staging get deploy url-shortener-api \
    -o jsonpath='{.spec.template.spec.containers[0].image}')
  echo "[$(date +%T)] image=$IMG"
  [[ "$IMG" == *"-test" ]] && break
  sleep 10
done

LIVE_TIME=$(date +%s)
echo "PR→live: $((LIVE_TIME - PUSH_TIME))s"

# Restore the original tag
git revert HEAD --no-edit && git push origin main
```

Pass: convergence time ≤ 180 seconds

### TC-3.2 — Manual force-sync is instantaneous

```bash
# Commit a change
git commit --allow-empty -m "qa: force-sync test"
git push origin main

# Force-sync immediately (bypasses poll interval)
argocd app sync api-staging --prune --insecure
argocd app wait api-staging --health --timeout 60 --insecure
```

Pass: `api-staging` reaches Synced+Healthy within 60 seconds

---

## Phase 4 — Prune validation

**Objective:** Confirm that resources deleted from git are pruned from the cluster.

### TC-4.1 — Pruned resource disappears from cluster

```bash
# Step 1: create a test ConfigMap in the dev overlay
cat >> k8s/overlays/dev/kustomization.yaml << 'EOF'
configMapGenerator:
  - name: qa-prune-test
    literals:
      - test=prune-me
    options:
      disableNameSuffixHash: true
EOF
git add k8s/overlays/dev/kustomization.yaml
git commit -m "qa: add prune test ConfigMap"
git push origin main
argocd app sync api-dev --prune --insecure
kubectl -n api-dev get cm qa-prune-test  # should exist

# Step 2: remove the ConfigMap from git
git revert HEAD --no-edit && git push origin main
argocd app sync api-dev --prune --insecure

# Step 3: verify it's gone
kubectl -n api-dev get cm qa-prune-test 2>&1 | grep "not found"
```

Pass: second `kubectl get cm` returns `not found`

---

## Phase 5 — Rollback via git revert

**Objective:** Confirm that `git revert` is sufficient to roll back a deploy.

### TC-5.1 — git revert restores previous image tag

```bash
ORIGINAL_TAG=$(kubectl -n api-prod get deploy url-shortener-api \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

# Deploy a "bad" version
sed -i '' 's/newTag: "v1.0.0"/newTag: "v1.0.0-bad"/' \
  k8s/overlays/prod/kustomization.yaml
git add k8s/overlays/prod/kustomization.yaml
git commit -m "qa: bad deploy for rollback test"
git push origin main
argocd app sync api-prod --insecure
sleep 30

# Rollback
git revert HEAD --no-edit
git push origin main
argocd app sync api-prod --insecure
argocd app wait api-prod --health --timeout 120 --insecure

CURRENT_IMG=$(kubectl -n api-prod get deploy url-shortener-api \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "Original: $ORIGINAL_TAG"
echo "After rollback: $CURRENT_IMG"
[[ "$CURRENT_IMG" == "$ORIGINAL_TAG" ]] && echo "PASS" || echo "FAIL"
```

Pass: image tag restored to original value

---

## Phase 6 — External Secrets Operator

**Objective:** Confirm ESO generates K8s Secrets from ExternalSecret CRDs.

### TC-6.1 — ESO controller is running

```bash
kubectl -n external-secrets-system get deploy external-secrets \
  -o jsonpath='{.status.availableReplicas}'; echo
```

Pass: `1` (or more)

### TC-6.2 — ExternalSecret resolves to a K8s Secret

```bash
kubectl -n api-dev get externalsecret url-shortener-db-creds \
  -o jsonpath='{.status.conditions[0].type}'; echo
# Expected: Ready
kubectl -n api-dev get secret url-shortener-db-creds
```

Pass: `Ready` status; Secret exists with `DATABASE_URL` key

### TC-6.3 — Secret value not in git

```bash
git log --all --oneline -- k8s/base/externalsecret.yaml | head -5
grep -r "password\|secret\|creds" k8s/base/externalsecret.yaml | grep -v "secretKey\|remoteRef\|name:"
```

Pass: no raw secret values appear in git history or the ExternalSecret file

---

## Phase 7 — Performance

**Objective:** Confirm api-prod meets the p95 < 150ms SLA under load.

### TC-7.1 — k6 smoke test baseline

```bash
kubectl -n api-prod port-forward svc/url-shortener-api 8090:80 &
sleep 2
k6 run tests/k6/smoke.js
```

Pass:
- `http_req_duration p(95) < 150ms`
- `http_req_failed = 0.00%`
- `http_reqs rate ≥ 1500/s`

### TC-7.2 — Zero dropped requests during rolling update

```bash
# Terminal 1: run k6 continuously
kubectl -n api-prod port-forward svc/url-shortener-api 8090:80 &
k6 run --duration 3m tests/k6/smoke.js &

# Terminal 2: trigger a rolling update mid-test
argocd app sync api-prod --prune --insecure

# After test completes, check results
# Pass: http_req_failed = 0.00% throughout
```

Pass: zero HTTP errors during rolling update window

---

## Summary scorecard

| Phase | Tests | Critical | Automated |
|-------|-------|---------|-----------|
| Bootstrap | TC-1.1 – 1.5 | TC-1.2, TC-1.3 | `make sync && make status` |
| Drift heal | TC-2.1 – 2.4 | TC-2.2, TC-2.4 | `make drift-demo` |
| Convergence | TC-3.1 – 3.2 | TC-3.1 | manual |
| Prune | TC-4.1 | TC-4.1 | manual |
| Rollback | TC-5.1 | TC-5.1 | `make rollback` |
| ESO | TC-6.1 – 6.3 | TC-6.2 | manual |
| Performance | TC-7.1 – 7.2 | TC-7.1, TC-7.2 | `make perf` |

**Definition of done:** All Critical tests pass. Heal time ≤ 180s. p95 ≤ 150ms. Zero errors during rolling update.
