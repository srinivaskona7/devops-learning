#!/usr/bin/env bash
# Recreate strategy demo
# Apply v1, run continuous curl, patch to v2, observe DOWNTIME, verify v2.
set -euo pipefail

NS="${NS:-default}"
APP=hello-recreate

echo "==> Applying v1 (image:1.0)"
kubectl apply -n "$NS" -f "$(dirname "$0")/deployment.yaml"
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s

echo "==> Pods (watch in another terminal: kubectl get pods -L version --watch)"
kubectl get pods -n "$NS" -l app=$APP -L version

echo "==> Starting background curl loop (port-forward)"
kubectl port-forward -n "$NS" svc/$APP 8080:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

(
  for i in $(seq 1 60); do
    OUT=$(curl -fsS --max-time 1 http://localhost:8080/ 2>&1 || echo "DOWN")
    echo "[$(date +%T)] $OUT" | head -c 120
    echo
    sleep 1
  done
) &
CURL_PID=$!

sleep 5

echo
echo "==> Patching image to v2 (image:2.0) — expect DOWNTIME window"
kubectl set image -n "$NS" deployment/$APP hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s

echo
echo "==> Verify v2"
kubectl get pods -n "$NS" -l app=$APP -L version

wait $CURL_PID || true

echo
echo "==> Done. Cleanup with:"
echo "    kubectl delete -f $(dirname "$0")/deployment.yaml"
