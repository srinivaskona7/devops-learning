#!/usr/bin/env bash
# Rollback demo: v1 -> v2 -> rollback to v1 -> forward to v2 again.
set -euo pipefail

NS="${NS:-default}"
APP=hello-rollback

echo "==> Create Deployment v1 + Service"
cat <<EOF | kubectl apply -n "$NS" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP
spec:
  replicas: 3
  revisionHistoryLimit: 10
  selector: { matchLabels: { app: $APP } }
  template:
    metadata:
      labels: { app: $APP, version: v1 }
    spec:
      containers:
        - name: hello
          image: gcr.io/google-samples/hello-app:1.0
          ports: [{ containerPort: 8080 }]
          readinessProbe:
            httpGet: { path: /, port: 8080 }
            initialDelaySeconds: 2
            periodSeconds: 2
          resources:
            requests: { cpu: 10m, memory: 16Mi }
            limits:   { cpu: 100m, memory: 64Mi }
---
apiVersion: v1
kind: Service
metadata: { name: $APP }
spec:
  selector: { app: $APP }
  ports: [{ port: 80, targetPort: 8080 }]
EOF

kubectl rollout status -n "$NS" deployment/$APP --timeout=120s

echo "==> History after v1"
kubectl rollout history -n "$NS" deployment/$APP

echo "==> Update to v2 (with annotation for the change cause)"
kubectl annotate -n "$NS" deployment/$APP \
  kubernetes.io/change-cause="upgrade to image:2.0" --overwrite
kubectl set image -n "$NS" deployment/$APP hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s

echo "==> History after v2"
kubectl rollout history -n "$NS" deployment/$APP

echo "==> Pretend v2 is broken — ROLLBACK"
kubectl rollout undo -n "$NS" deployment/$APP
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s
kubectl get pods -n "$NS" -l app=$APP -L version

echo "==> Roll FORWARD again to a specific revision"
kubectl rollout history -n "$NS" deployment/$APP
LAST_GOOD=$(kubectl rollout history -n "$NS" deployment/$APP --output=jsonpath='{range .items[*]}{.revision}{"\n"}{end}' 2>/dev/null | tail -1 || true)
# Fallback: just undo again to ping-pong forward
kubectl rollout undo -n "$NS" deployment/$APP
kubectl rollout status -n "$NS" deployment/$APP --timeout=120s

echo "==> Final image:"
kubectl get -n "$NS" deployment/$APP -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

echo "==> Cleanup with: kubectl delete deployment/$APP svc/$APP -n $NS"
