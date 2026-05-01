#!/usr/bin/env bash
# drift-and-heal.sh — Introduce drift into a Deployment, measure the time
# Argo CD takes to detect it and converge the cluster back to the git state.
#
# Usage:
#   bash tests/e2e/drift-and-heal.sh [NAMESPACE] [DEPLOYMENT]
#
# Defaults:
#   NAMESPACE  = api-prod
#   DEPLOYMENT = url-shortener-api
#
# Environment:
#   ARGOCD_APP      — Argo CD Application name (default: derived from namespace)
#   MAX_HEAL_SECS   — fail if heal takes longer than this (default: 180)
#   DESIRED_REPLICAS — expected replica count after heal (default: 3)

set -euo pipefail

NAMESPACE="${1:-api-prod}"
DEPLOYMENT="${2:-url-shortener-api}"
ARGOCD_APP="${ARGOCD_APP:-api-prod}"
MAX_HEAL_SECS="${MAX_HEAL_SECS:-180}"
DESIRED_REPLICAS="${DESIRED_REPLICAS:-3}"

# ── colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[$(date +%T)] ✔${NC}  $*"; }
info() { echo -e "${YELLOW}[$(date +%T)] ▶${NC}  $*"; }
fail() { echo -e "${RED}[$(date +%T)] ✘${NC}  $*" >&2; exit 1; }
step() { echo -e "${CYAN}[$(date +%T)] ──${NC}  $*"; }

# ── preflight ─────────────────────────────────────────────────────────────────
info "Preflight checks..."
command -v kubectl >/dev/null || fail "kubectl not found"

CURRENT_REPLICAS=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
[[ -z "$CURRENT_REPLICAS" ]] && fail "Deployment $DEPLOYMENT not found in namespace $NAMESPACE"
ok "Deployment found — current replicas: $CURRENT_REPLICAS"

if [[ "$CURRENT_REPLICAS" != "$DESIRED_REPLICAS" ]]; then
  info "Warning: current replicas ($CURRENT_REPLICAS) ≠ desired ($DESIRED_REPLICAS)."
  info "This test assumes the app is at its git-desired state before we introduce drift."
fi

# ── step 1: record baseline ────────────────────────────────────────────────────
echo ""
step "STEP 1 — Record baseline"
BASELINE_IMAGE=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
ok "Baseline image: $BASELINE_IMAGE"
ok "Baseline replicas: $CURRENT_REPLICAS"

# ── step 2: introduce drift ───────────────────────────────────────────────────
echo ""
step "STEP 2 — Introduce drift (scale to 0)"
DRIFT_START=$(date +%s)
kubectl -n "$NAMESPACE" scale deploy "$DEPLOYMENT" --replicas=0
ok "Scaled $DEPLOYMENT to 0 replicas at $(date +%T)"

# Verify the drift took effect
sleep 3
LIVE_REPLICAS=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.spec.replicas}')
[[ "$LIVE_REPLICAS" == "0" ]] || fail "Scale command did not take effect (replicas=$LIVE_REPLICAS)"
ok "Drift confirmed: live replicas = 0"

# ── step 3: detect OutOfSync ──────────────────────────────────────────────────
echo ""
step "STEP 3 — Waiting for Argo CD to detect OutOfSync..."
DETECT_START=$(date +%s)
DETECTED=false

while true; do
  ELAPSED=$(( $(date +%s) - DETECT_START ))
  if [[ $ELAPSED -gt $MAX_HEAL_SECS ]]; then
    fail "TIMEOUT: drift not detected after ${MAX_HEAL_SECS}s"
  fi

  SYNC_STATUS=$(kubectl -n argocd get application "$ARGOCD_APP" \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")

  echo -e "  [+${ELAPSED}s] sync.status=${SYNC_STATUS}"

  if [[ "$SYNC_STATUS" == "OutOfSync" ]]; then
    DETECTED=true
    DETECT_TIME=$(( $(date +%s) - DRIFT_START ))
    ok "Drift detected in ${DETECT_TIME}s"
    break
  fi

  sleep 5
done

# ── step 4: wait for auto-heal ────────────────────────────────────────────────
echo ""
step "STEP 4 — Waiting for self-heal (replicas → ${DESIRED_REPLICAS})..."

HEAL_TIMEOUT=$(( DRIFT_START + MAX_HEAL_SECS ))

while true; do
  NOW=$(date +%s)
  if [[ $NOW -gt $HEAL_TIMEOUT ]]; then
    READY_NOW=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    fail "TIMEOUT: replicas not restored after ${MAX_HEAL_SECS}s (readyReplicas=${READY_NOW})"
  fi

  ELAPSED=$(( NOW - DRIFT_START ))
  READY=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  SYNC_STATUS=$(kubectl -n argocd get application "$ARGOCD_APP" \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")

  echo -e "  [+${ELAPSED}s] readyReplicas=${READY}  sync=${SYNC_STATUS}"

  if [[ "$READY" == "$DESIRED_REPLICAS" ]] && [[ "$SYNC_STATUS" == "Synced" ]]; then
    HEAL_TIME=$(( NOW - DRIFT_START ))
    break
  fi

  sleep 5
done

# ── step 5: verify final state ────────────────────────────────────────────────
echo ""
step "STEP 5 — Final state verification"

FINAL_REPLICAS=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.spec.replicas}')
FINAL_READY=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.status.readyReplicas}')
FINAL_IMAGE=$(kubectl -n "$NAMESPACE" get deploy "$DEPLOYMENT" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')
FINAL_SYNC=$(kubectl -n argocd get application "$ARGOCD_APP" \
  -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
FINAL_HEALTH=$(kubectl -n argocd get application "$ARGOCD_APP" \
  -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

ok "spec.replicas:  $FINAL_REPLICAS (desired: $DESIRED_REPLICAS)"
ok "readyReplicas:  $FINAL_READY"
ok "image:          $FINAL_IMAGE"
ok "sync.status:    $FINAL_SYNC"
ok "health.status:  $FINAL_HEALTH"

# ── result ────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
if [[ "$FINAL_REPLICAS" == "$DESIRED_REPLICAS" ]] && \
   [[ "$FINAL_SYNC" == "Synced" ]] && \
   [[ "$FINAL_HEALTH" == "Healthy" ]] && \
   [[ $HEAL_TIME -le $MAX_HEAL_SECS ]]; then
  echo -e "${GREEN}PASS${NC}: heal_time=${HEAL_TIME}s  (SLA: ≤ ${MAX_HEAL_SECS}s)"
  echo "  drift_detected_at:  +${DETECT_TIME}s"
  echo "  fully_healed_at:    +${HEAL_TIME}s"
  echo "  replicas_restored:  ${FINAL_REPLICAS}/${DESIRED_REPLICAS}"
  echo "════════════════════════════════════════════════════════"
  exit 0
else
  echo -e "${RED}FAIL${NC}: heal_time=${HEAL_TIME}s  (SLA: ≤ ${MAX_HEAL_SECS}s)"
  echo "  Final sync: $FINAL_SYNC"
  echo "  Final health: $FINAL_HEALTH"
  echo "  Final replicas: $FINAL_REPLICAS (expected: $DESIRED_REPLICAS)"
  echo "════════════════════════════════════════════════════════"
  exit 1
fi
