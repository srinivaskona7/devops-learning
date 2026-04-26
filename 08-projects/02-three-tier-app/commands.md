# Project 02 (Three-Tier App on Kubernetes) — Commands

> Quick pickup reference. Full walkthrough in `README.md`.

## Prerequisites
```bash
helm version              # 3.12+
kubectl get sc            # default StorageClass present
kubectl get nodes
# Optional: ingress-nginx for app.local
kubectl -n ingress-nginx get svc ingress-nginx-controller
```

## Build
```bash
cd 08-projects/02-three-tier-app

helm lint   ./helm/three-tier
helm template demo ./helm/three-tier | less
```

## Deploy
```bash
kubectl create namespace proj02

helm -n proj02 install demo ./helm/three-tier \
  --set postgres.password='ChangeMe123!' \
  --set ingress.host=app.local \
  --wait --timeout 5m

# Upgrade pattern (bump values without reinstall)
helm -n proj02 upgrade demo ./helm/three-tier \
  --reuse-values --set backend.replicas=3
```

## Verify
```bash
kubectl -n proj02 get pods,svc,statefulset,ingress
kubectl -n proj02 wait --for=condition=ready pod -l tier=backend --timeout=120s

# Port-forward smoke test (no ingress required)
kubectl -n proj02 port-forward svc/demo-frontend 8080:80 &
PF_PID=$!

curl -s http://localhost:8080/ | head -5
curl -s http://localhost:8080/api/health   # -> {"status":"ok"}
curl -s http://localhost:8080/api/users    # -> []

# Persistence drill
curl -sX POST http://localhost:8080/api/users \
  -H 'content-type: application/json' \
  -d '{"name":"alice"}'

kubectl -n proj02 delete pod demo-postgres-0
kubectl -n proj02 wait --for=condition=ready pod demo-postgres-0 --timeout=120s
curl -s http://localhost:8080/api/users    # alice still there

kill $PF_PID
```

## Cleanup
```bash
helm -n proj02 uninstall demo
kubectl -n proj02 delete pvc -l app.kubernetes.io/name=three-tier
kubectl delete namespace proj02
```

## One-liners worth memorising
```bash
# In-cluster Postgres shell
kubectl -n proj02 exec -it demo-postgres-0 -- psql -U postgres

# Tail backend logs
kubectl -n proj02 logs -l tier=backend -f --tail=50

# Inspect rendered manifests for one template
helm template demo ./helm/three-tier --show-only templates/backend.yaml

# Diff before upgrade (requires helm-diff plugin)
helm -n proj02 diff upgrade demo ./helm/three-tier --reuse-values

# Service DNS quick check from a debug pod
kubectl -n proj02 run dns --rm -it --image=busybox --restart=Never -- \
  nslookup demo-postgres
```
