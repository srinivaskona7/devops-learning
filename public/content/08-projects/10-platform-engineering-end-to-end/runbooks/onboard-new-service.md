# Runbook: Onboard a New Service to the Platform

**Audience:** Platform engineers, senior engineers onboarding their first service
**Time to complete:** 15–45 minutes
**Prerequisites:** kind cluster running, `make bootstrap` completed, Backstage accessible

---

## Overview

This runbook walks through onboarding a new service onto the Vanta Pay platform. After completing this runbook, the service will have:

- Canary delivery via Argo Rollouts
- Istio mTLS and traffic management
- Prometheus metrics + Grafana dashboard
- Loki log collection
- Tempo distributed tracing
- Vault-managed secrets via External Secrets Operator
- Kyverno policy compliance
- Cosign image signing
- Chaos Mesh resilience experiments

---

## Step 1: Prerequisites checklist

Before starting, verify the platform is healthy:

```bash
# All platform pods should be Running
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n istio-system
kubectl get pods -n vault
kubectl get pods -n external-secrets
kubectl get pods -n kyverno
kubectl get pods -n chaos-mesh

# ArgoCD app-of-apps should be Synced/Healthy
kubectl argo rollouts list rollouts --all-namespaces
argocd app list
```

Expected: all apps show `Synced` and `Healthy`.

---

## Step 2: Choose a service name and SLO tier

| Criteria | Bronze | Silver | Gold |
|----------|--------|--------|------|
| Customer-facing? | No | Partially | Yes |
| Revenue impact if down? | None | Low | Direct |
| Acceptable error budget | 1% / month | 0.5% / month | 0.1% / month |
| p95 latency target | 500ms | 300ms | 150ms |
| On-call escalation | Slack only | PagerDuty warn | PagerDuty page |

Choose your service name (lowercase, hyphenated, 3–40 characters).

---

## Step 3: Scaffold the service via Backstage

### Option A: Backstage UI (recommended)

1. Open Backstage: https://backstage.vantapay.io
2. Click **Create** → **Platform Golden Path — New Service**
3. Fill in the form:
   - Service name: `<your-service-name>`
   - Team: `<your-team>`
   - SLO tier: `<bronze|silver|gold>`
   - Language: `go`
4. Click **Create**
5. Wait for the GitHub PR to be created and the scaffold to be merged

### Option B: make command (for automation)

```bash
# From this project root
make onboard-demo SERVICE=my-new-service TEAM=payments TIER=gold

# This runs the Backstage scaffolder via API:
curl -X POST https://backstage.vantapay.io/api/scaffolder/v2/tasks \
  -H "Authorization: Bearer $(vault kv get -field=backstage_token secret/platform)" \
  -d @- <<EOF
{
  "templateRef": "template:default/platform-golden-path",
  "values": {
    "name": "my-new-service",
    "team": "payments",
    "slo_tier": "gold",
    "language": "go",
    "port": 8080,
    "replicas": 3
  }
}
EOF
```

---

## Step 4: Verify Argo CD registered the new service

```bash
# The Backstage template creates an Argo CD Application automatically
argocd app get my-new-service

# Expected output:
# Name:               my-new-service
# Project:            services
# Server:             https://kubernetes.default.svc
# Namespace:          payments
# URL:                https://argocd.vantapay.io/applications/my-new-service
# Repo:               https://github.com/vantapay/my-new-service
# Target:             main
# Path:               k8s
# SyncStatus:         OutOfSync (initial state — no image built yet)
# HealthStatus:       Healthy
```

---

## Step 5: Build and sign the first image

In the new service repository:

```bash
# Clone the scaffold repo
git clone https://github.com/vantapay/my-new-service
cd my-new-service

# Build the image
make docker-build VERSION=0.0.1

# Scan for vulnerabilities (must pass before push)
make docker-scan VERSION=0.0.1

# Push to registry
make docker-push VERSION=0.0.1

# Sign the image (keyless — uses GitHub Actions OIDC in CI)
# For local development, use personal OIDC:
make docker-sign VERSION=0.0.1
```

In CI (GitHub Actions), the build-and-sign workflow runs automatically on push to `main`.

---

## Step 6: Seed Vault secrets

Every new service needs its secrets seeded in Vault before the first pod can start:

```bash
# Authenticate to Vault
vault auth login

# Seed the service's secret path (replace placeholder values)
vault kv put secret/my-new-service \
  db_password=$(openssl rand -base64 32) \
  api_key=$(openssl rand -hex 32) \
  jwt_secret=$(openssl rand -base64 64)

# Verify the secret is accessible by the service account
vault token lookup
vault kv get secret/my-new-service
```

---

## Step 7: Configure Vault Kubernetes auth for the new service

```bash
# Create a Vault policy for the service
vault policy write my-new-service - <<EOF
path "secret/data/my-new-service" {
  capabilities = ["read"]
}
path "secret/metadata/my-new-service" {
  capabilities = ["read"]
}
EOF

# Bind the Kubernetes ServiceAccount to the Vault policy
vault write auth/kubernetes/role/my-new-service \
  bound_service_account_names=my-new-service \
  bound_service_account_namespaces=payments \
  policies=my-new-service \
  ttl=1h

# Verify ESO can sync the secret
kubectl apply -f k8s/externalsecret.yaml
kubectl get externalsecret -n payments my-new-service-secrets
# STATUS should show "SecretSynced" within 10 seconds
```

---

## Step 8: Trigger the first deploy

```bash
# Update the image tag in the Rollout manifest
sed -i 's|:0.0.1|:0.0.1|g' k8s/rollout.yaml   # already 0.0.1, no-op for first deploy
git add k8s/rollout.yaml
git commit -m "feat: initial deploy"
git push origin main

# Argo CD will sync within 2 minutes (or force sync):
argocd app sync my-new-service

# Watch the rollout
kubectl argo rollouts get rollout my-new-service -n payments --watch
```

Expected: `Status: Healthy` within 2 minutes.

---

## Step 9: Verify all platform capabilities are wired

```bash
# 1. Check pod is running with correct labels
kubectl get pods -n payments -l app=my-new-service --show-labels

# 2. Verify ServiceMonitor was created and Prometheus is scraping
kubectl get servicemonitor -n payments my-new-service
# Should appear in Prometheus targets: http://prometheus:9090/targets

# 3. Check ExternalSecret is synced
kubectl get externalsecret -n payments my-new-service-secrets
# STATUS: SecretSynced

# 4. Verify mTLS is working
istioctl authn tls-check my-new-service-stable.payments.svc.cluster.local

# 5. Check Kyverno policy compliance
kubectl get policyreport -n payments -o jsonpath='{.items[*].summary}'
# Should show: pass=5 fail=0

# 6. Verify image signature
cosign verify \
  --certificate-identity-regexp "https://github.com/vantapay/my-new-service.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/vantapay/my-new-service:0.0.1

# 7. Send a test request
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s http://my-new-service-stable.payments.svc.cluster.local/healthz
```

---

## Step 10: Open the Grafana dashboard

```bash
# Open the auto-provisioned dashboard
open "https://grafana.vantapay.io/d/platform-my-new-service"
```

The dashboard is provisioned by the platform via ConfigMap when the service's labels match. Allow 60 seconds after first pod start for metrics to appear.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Pod stuck `ContainerCreating` | ExternalSecret not synced — Vault auth not configured | Step 7 |
| Pod blocked at admission | Kyverno policy violation | `kubectl get policyreport -n payments` |
| Pod blocked at admission (signature) | Image not signed or wrong issuer | `cosign verify ...` |
| Argo CD shows `OutOfSync` indefinitely | Image tag not updated in GitOps repo | `argocd app sync my-new-service` |
| ServiceMonitor not scraped | Label `monitoring: platform` missing from ServiceMonitor | Check labels |
| Vault `permission denied` | SA not bound to Vault role | Step 7 |

---

## Completion checklist

- [ ] Service scaffolded and GitHub repo created
- [ ] First image built, scanned, pushed, and signed
- [ ] Vault secrets seeded and ESO syncing
- [ ] First deploy successful via Argo CD
- [ ] Pod Running with all required labels
- [ ] Kyverno policy reports show 0 violations
- [ ] ServiceMonitor scraped by Prometheus
- [ ] Grafana dashboard showing RED metrics
- [ ] mTLS enforced (istioctl tls-check passes)
- [ ] Backstage catalog entry visible
- [ ] On-call routing configured in PagerDuty for the team
