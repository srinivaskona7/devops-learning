# Runbook: Upgrade the Platform

**Audience:** Platform engineers
**Frequency:** Monthly (minor), Quarterly (major)
**Time to complete:** 2–4 hours
**Risk:** Medium — Istio and Kyverno upgrades require careful sequencing

---

## Upgrade sequencing (critical — must follow this order)

```
1. cert-manager          (Istio depends on it for TLS)
2. Kyverno               (admission controller — upgrade in permissive mode)
3. Istio (istiod first)  (control plane before data plane)
4. Vault                 (secrets plane — upgrade with active/standby)
5. External Secrets Operator
6. Argo CD               (GitOps controller)
7. Argo Rollouts         (delivery controller)
8. Prometheus/Grafana/Loki/Tempo (observability — can be done anytime)
9. Chaos Mesh            (chaos controller — last, not critical path)
10. Backstage            (portal — non-critical path)
```

**Never upgrade Istio and Kyverno simultaneously.** If both break, admission control is gone.

---

## Pre-upgrade checklist

```bash
# 1. Check current versions
kubectl get pods -n istio-system -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
kubectl get pods -n kyverno -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
helm list --all-namespaces

# 2. Check all apps are healthy before starting
argocd app list
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# 3. Check SLO burn rate — do NOT upgrade during elevated burn
# If burn rate > 2×, defer upgrade
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
# Visit: http://localhost:9090/graph?g0.expr=slo%3Aerror_budget_remaining%3Aratio

# 4. Notify teams of maintenance window
# Post to #engineering: "Platform maintenance: [start time] - [estimated end time]. 
# Zero downtime expected. Contact #platform-support with concerns."

# 5. Take a snapshot of the GitOps repo
git -C /path/to/platform-gitops log --oneline -5
```

---

## Step 1: Upgrade cert-manager

```bash
# Check current version
helm list -n cert-manager

# Check cert-manager release notes: https://cert-manager.io/docs/release-notes/

# Upgrade
helm repo update
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.14.0 \
  --set installCRDs=true \
  --wait --timeout=5m

# Verify
kubectl rollout status deployment/cert-manager -n cert-manager
kubectl get certificates --all-namespaces
```

---

## Step 2: Upgrade Kyverno

**Critical:** Switch to PERMISSIVE mode before upgrading to avoid blocking admission.

```bash
# Step 2a: Temporarily set policies to audit mode
kubectl patch clusterpolicy --all -p '{"spec":{"validationFailureAction":"Audit"}}' --type merge

# Verify no policies are in Enforce mode
kubectl get clusterpolicy -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.validationFailureAction}{"\n"}{end}'

# Step 2b: Upgrade Kyverno
helm upgrade kyverno kyverno/kyverno \
  --namespace kyverno \
  --version v3.1.0 \
  --wait --timeout=10m

# Step 2c: Wait for Kyverno pods to be Ready
kubectl rollout status deployment/kyverno -n kyverno

# Step 2d: Run a quick policy test
kubectl apply --dry-run=server -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-policy
  namespace: payment
  labels:
    app: test
    version: "1.0"
    team: payments
spec:
  containers:
    - name: test
      image: nginx
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
      readinessProbe:
        httpGet: {path: /healthz, port: 8080}
      livenessProbe:
        httpGet: {path: /healthz, port: 8080}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
EOF

# Expected: "pod/test-policy created (server dry run)"

# Step 2e: Switch policies back to Enforce mode
kubectl patch clusterpolicy --all -p '{"spec":{"validationFailureAction":"Enforce"}}' --type merge
```

---

## Step 3: Upgrade Istio (canary control plane upgrade)

Istio supports running two control planes simultaneously, enabling a safe canary upgrade.

```bash
# Step 3a: Install new Istio version alongside existing
ISTIO_NEW_VERSION=1.21.0
istioctl install --set revision=$ISTIO_NEW_VERSION --set profile=default

# Step 3b: Verify new istiod is running
kubectl get pods -n istio-system -l istio.io/rev=$ISTIO_NEW_VERSION

# Step 3c: Migrate one namespace at a time (start with non-critical)
# Remove old revision label, add new
kubectl label namespace fraud istio.io/rev=$ISTIO_NEW_VERSION --overwrite
kubectl rollout restart deployment -n fraud
kubectl rollout status deployment -n fraud

# Verify mTLS is still enforced
istioctl authn tls-check fraud-service.fraud.svc.cluster.local

# Step 3d: Migrate payment namespace (gold SLO — extra caution)
# Wait 24h after fraud migration before proceeding
kubectl label namespace payment istio.io/rev=$ISTIO_NEW_VERSION --overwrite
kubectl argo rollouts restart payment-service -n payment
kubectl argo rollouts get rollout payment-service -n payment --watch

# Step 3e: After all namespaces migrated, remove old control plane
istioctl uninstall --revision default
```

---

## Step 4: Upgrade Vault

Vault upgrades require the active + standby pod strategy.

```bash
# Check current Vault version and mode
kubectl exec -n vault vault-0 -- vault status

# Upgrade Vault using Helm (HA mode — standby updated first)
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --version 0.27.0 \
  --set server.ha.enabled=true \
  --wait --timeout=15m

# Vault will perform a rolling upgrade:
# 1. vault-1 (standby) upgrades first
# 2. vault-2 (standby) upgrades
# 3. vault-0 (active) steps down, upgrades, re-elects leader

# Monitor the upgrade
kubectl get pods -n vault --watch

# Verify Vault is unsealed and active after upgrade
kubectl exec -n vault vault-0 -- vault status
```

---

## Step 5: Upgrade Argo CD

```bash
# Check Argo CD version
argocd version

# Upgrade
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --version 6.7.0 \
  --wait --timeout=10m

# Verify all apps are still healthy after upgrade
argocd app list

# Re-sync if any app shows OutOfSync
argocd app sync <app-name>
```

---

## Step 6: Upgrade Prometheus/Grafana stack

```bash
# Upgrade kube-prometheus-stack
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 57.0.0 \
  --values platform/observability/values.yaml \
  --wait --timeout=15m

# Verify Prometheus is scraping correctly (targets should still be up)
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
# Check: http://localhost:9090/targets
```

---

## Post-upgrade verification

```bash
# 1. All platform pods Running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed | grep -v Terminating

# 2. All Argo CD apps Synced/Healthy
argocd app list | grep -v Synced

# 3. SLO metrics still flowing
# Check Grafana dashboards for each service

# 4. Run a test canary deploy
make onboard-demo SERVICE=upgrade-test TEAM=platform TIER=bronze
sleep 60
kubectl argo rollouts get rollout upgrade-test -n platform
# Should show Healthy

# 5. Verify Kyverno policies enforcing
kubectl apply --dry-run=server - <<EOF
# ... invalid pod spec (missing labels) ...
EOF
# Should be rejected

# 6. Verify mTLS across all namespaces
istioctl analyze --all-namespaces

# 7. Clean up test service
argocd app delete upgrade-test
kubectl delete namespace upgrade-test --ignore-not-found
```

---

## Rollback procedure

If the upgrade causes problems:

```bash
# Roll back a Helm release to the previous version
helm rollback <release-name> -n <namespace>

# Roll back Istio control plane
istioctl uninstall --revision $ISTIO_NEW_VERSION
kubectl label namespace payment istio.io/rev- --overwrite  # remove revision label
kubectl rollout restart deployment -n payment

# Roll back Vault (if needed — rare; Vault data is not affected by binary rollback)
helm rollback vault -n vault
```
