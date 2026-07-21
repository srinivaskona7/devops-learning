#!/usr/bin/env bash
# Manual canary demo: 9 stable + 1 canary, observe ~90/10 split, then promote.
set -euo pipefail

NS="${NS:-default}"
HERE="$(dirname "$0")"

echo "==> Apply stable + service"
kubectl apply -n "$NS" -f "$HERE/deployment-stable.yaml" -f "$HERE/service.yaml"
kubectl rollout status -n "$NS" deployment/hello-stable --timeout=120s

echo "==> Apply canary"
kubectl apply -n "$NS" -f "$HERE/deployment-canary.yaml"
kubectl rollout status -n "$NS" deployment/hello-canary --timeout=120s

kubectl get pods -n "$NS" -l app=hello-canary-app -L track,version
kubectl get endpoints -n "$NS" hello-canary-app

echo "==> Port-forward + 100 requests to observe split"
kubectl port-forward -n "$NS" svc/hello-canary-app 8083:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

echo "Hit distribution:"
for i in $(seq 1 100); do
  curl -fsS --max-time 1 http://localhost:8083/ 2>/dev/null | grep -oE 'Version: [0-9.]+' || true
done | sort | uniq -c

echo
echo "==> Promoting canary (scale canary -> 9, stable -> 0)"
kubectl scale -n "$NS" deployment/hello-canary --replicas=9
kubectl rollout status -n "$NS" deployment/hello-canary --timeout=120s
kubectl scale -n "$NS" deployment/hello-stable --replicas=0

sleep 5
echo "Post-promotion distribution:"
for i in $(seq 1 30); do
  curl -fsS --max-time 1 http://localhost:8083/ 2>/dev/null | grep -oE 'Version: [0-9.]+' || true
done | sort | uniq -c

echo "==> Done. To abort instead next time:  kubectl scale deploy/hello-canary --replicas=0"
