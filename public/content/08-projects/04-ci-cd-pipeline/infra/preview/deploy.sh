#!/usr/bin/env bash
# infra/preview/deploy.sh
# Deploy a PR image to an isolated preview namespace.
#
# Usage: deploy.sh <pr-number> <image-ref>
# Example: deploy.sh 42 ghcr.io/org/app@sha256:abc123
#
# Assumes KUBECONFIG is already configured (done by the calling workflow).

set -euo pipefail

PR_NUMBER="${1:?PR_NUMBER is required}"
IMAGE="${2:?IMAGE is required}"
NAMESPACE="pr-${PR_NUMBER}"
APP_NAME="cicd-demo"
PREVIEW_HOST="pr-${PR_NUMBER}.preview.example.com"

log() { echo "[deploy] $*" >&2; }

log "Deploying PR #${PR_NUMBER}"
log "Image: ${IMAGE}"
log "Namespace: ${NAMESPACE}"

# ── Create namespace if it doesn't exist ─────────────────────────────────────
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  log "Namespace ${NAMESPACE} already exists — updating deployment"
else
  log "Creating namespace ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}"
  # Label the namespace so network policies and monitoring can select it.
  kubectl label namespace "${NAMESPACE}" \
    app.kubernetes.io/managed-by=github-actions \
    preview=true \
    pr="${PR_NUMBER}"
fi

# ── Deploy the application ────────────────────────────────────────────────────
kubectl apply --namespace="${NAMESPACE}" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
    pr: "${PR_NUMBER}"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        pr: "${PR_NUMBER}"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${APP_NAME}
          image: ${IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: PORT
              value: "8080"
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "64Mi"
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
EOF

# ── Expose via Service ────────────────────────────────────────────────────────
kubectl apply --namespace="${NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${APP_NAME}
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
EOF

# ── Ingress (assumes nginx ingress controller in preview cluster) ─────────────
kubectl apply --namespace="${NAMESPACE}" -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: ${PREVIEW_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}
                port:
                  number: 80
EOF

# ── Wait for rollout ──────────────────────────────────────────────────────────
log "Waiting for rollout..."
kubectl rollout status deployment/"${APP_NAME}" \
  --namespace="${NAMESPACE}" \
  --timeout=120s

log "Preview live at: https://${PREVIEW_HOST}"
