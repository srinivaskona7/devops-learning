# Project 03 (GitOps with ArgoCD) — Commands

> Quick pickup reference. Full walkthrough in `README.md` and `argocd-install.md`.

## Prerequisites
```bash
kubectl get nodes
# Project 01 manifests reachable in your fork
git remote -v
# argocd CLI (optional but helpful)
argocd version --client || brew install argocd
```

## Build
Nothing to compile — manifests live in `apps/`. Edit `apps/root-app.yaml`:
- `repoURL`  → your fork
- `path`     → `08-projects/03-gitops-with-argocd/apps`
- Commit + push before applying.

## Deploy
```bash
# 1. Install ArgoCD (plain manifests)
ARGOCD_VERSION=v2.12.4
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=300s

# 2. Get bootstrap admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# 3. UI access
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
# https://localhost:8080  (admin / <password above>)

# 4. CLI login
argocd login localhost:8080 --username admin --insecure

# 5. Apply the app-of-apps root
kubectl apply -f apps/root-app.yaml
```

## Verify
```bash
kubectl -n argocd get applications
# root-app      Synced   Healthy
# hello-world   Synced   Healthy

argocd app list
argocd app get hello-world
argocd app diff hello-world

# Self-heal drill: introduce drift, watch reconciliation
kubectl -n proj01 scale deploy hello-world --replicas=10
kubectl -n argocd get application hello-world \
  -o jsonpath='{.status.sync.status}'; echo
sleep 60
kubectl -n proj01 get deploy hello-world   # back to 2 replicas
```

## Cleanup
```bash
kubectl -n argocd delete application root-app
kubectl delete namespace argocd
# Also remove the bootstrap secret if you kept it
kubectl -n argocd delete secret argocd-initial-admin-secret 2>/dev/null || true
```

## One-liners worth memorising
```bash
# Force sync from CLI
argocd app sync hello-world

# Hard refresh (re-clones git, ignores cache)
argocd app get hello-world --hard-refresh

# Show last sync result
kubectl -n argocd get app hello-world \
  -o jsonpath='{.status.operationState.message}'; echo

# Rotate admin password
argocd account update-password

# Watch all apps in one shot
watch -n2 'kubectl -n argocd get applications'
```
