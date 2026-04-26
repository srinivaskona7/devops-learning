#!/usr/bin/env bash
# Blue/Green demo: deploy both, switch selector atomically, optionally roll back.
set -euo pipefail

NS="${NS:-default}"
HERE="$(dirname "$0")"

echo "==> Deploying BLUE (v1) and Service"
kubectl apply -n "$NS" -f "$HERE/deployment-blue.yaml" -f "$HERE/service.yaml"
kubectl rollout status -n "$NS" deployment/hello-blue --timeout=120s

echo "==> Deploying GREEN (v2) — receives no traffic yet"
kubectl apply -n "$NS" -f "$HERE/deployment-green.yaml"
kubectl rollout status -n "$NS" deployment/hello-green --timeout=120s

kubectl get pods -n "$NS" -l app=hello-bg -L color,version

echo "==> Port-forward Service + curl loop"
kubectl port-forward -n "$NS" svc/hello-bg 8082:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

(
  for i in $(seq 1 30); do
    OUT=$(curl -fsS --max-time 1 http://localhost:8082/ 2>&1 || echo "DOWN")
    echo "[$(date +%T)] $OUT" | head -c 120; echo
    sleep 1
  done
) &
CURL_PID=$!

sleep 8

echo
echo "==> Atomic switch: BLUE -> GREEN"
kubectl patch svc -n "$NS" hello-bg \
  -p '{"spec":{"selector":{"app":"hello-bg","color":"green"}}}'

sleep 8

echo
echo "==> Rolling back: GREEN -> BLUE (instant)"
kubectl patch svc -n "$NS" hello-bg \
  -p '{"spec":{"selector":{"app":"hello-bg","color":"blue"}}}'

wait $CURL_PID || true

echo "==> Final selector:"
kubectl get svc -n "$NS" hello-bg -o jsonpath='{.spec.selector}'; echo

echo "==> Cleanup with:"
echo "    kubectl delete -f $HERE/deployment-blue.yaml -f $HERE/deployment-green.yaml -f $HERE/service.yaml"
