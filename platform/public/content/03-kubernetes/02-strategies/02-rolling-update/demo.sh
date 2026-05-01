#!/usr/bin/env bash
# RollingUpdate demo: zero downtime, mixed responses during transition.
set -euo pipefail

NS="${NS:-default}"
APP=hello-rolling

echo "==> Applying v1"
kubectl apply -n "$NS" -f "$(dirname "$0")/deployment.yaml"
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s
kubectl get pods -n "$NS" -l app=$APP -L version

echo "==> Port-forward + curl loop"
kubectl port-forward -n "$NS" svc/$APP 8081:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

(
  for i in $(seq 1 90); do
    OUT=$(curl -fsS --max-time 1 http://localhost:8081/ 2>&1 || echo "DOWN")
    echo "[$(date +%T)] $OUT" | head -c 120
    echo
    sleep 1
  done
) &
CURL_PID=$!

sleep 5

echo
echo "==> Updating image to v2 — expect mixed v1/v2 responses, NO downtime"
kubectl set image -n "$NS" deployment/$APP hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status -n "$NS" deployment/$APP --timeout=180s

echo
echo "==> History"
kubectl rollout history -n "$NS" deployment/$APP
kubectl get pods -n "$NS" -l app=$APP -L version

wait $CURL_PID || true
echo "==> Done."
