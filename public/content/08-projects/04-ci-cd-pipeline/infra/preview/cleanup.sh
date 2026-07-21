#!/usr/bin/env bash
# infra/preview/cleanup.sh
# Delete the preview namespace for a closed PR.
#
# Usage: cleanup.sh <pr-number>
# Example: cleanup.sh 42
#
# Assumes KUBECONFIG is already configured (done by the calling workflow).

set -euo pipefail

PR_NUMBER="${1:?PR_NUMBER is required}"
NAMESPACE="pr-${PR_NUMBER}"

log() { echo "[cleanup] $*" >&2; }

log "Cleaning up preview for PR #${PR_NUMBER}"
log "Namespace: ${NAMESPACE}"

if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  log "Deleting namespace ${NAMESPACE}..."
  kubectl delete namespace "${NAMESPACE}" --wait=true --timeout=60s
  log "Namespace ${NAMESPACE} deleted."
else
  log "Namespace ${NAMESPACE} not found — nothing to clean up."
fi
