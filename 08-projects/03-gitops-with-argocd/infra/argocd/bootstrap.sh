#!/usr/bin/env bash
# bootstrap.sh — Install Argo CD on the kind cluster, configure the admin
# password, and register the GitOps repository.
#
# Usage:
#   REPO_URL=https://github.com/<ORG>/Devops-learning \
#   ARGOCD_PASSWORD=MyStr0ngPass! \
#   bash infra/argocd/bootstrap.sh
#
# Environment variables:
#   REPO_URL          — your fork of this repository (required)
#   ARGOCD_PASSWORD   — desired admin password (default: ArgoCD@Lab123!)
#   ARGOCD_VERSION    — Argo CD manifest version (default: stable)
#   CONTEXT           — kubectl context (default: kind-gitops-lab)

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/YOUR-ORG/Devops-learning}"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-ArgoCD@Lab123!}"
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
CONTEXT="${CONTEXT:-kind-gitops-lab}"

# ── colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔${NC}  $*"; }
info() { echo -e "${YELLOW}▶${NC}  $*"; }
die()  { echo -e "${RED}✘${NC}  $*" >&2; exit 1; }

# ── preflight ─────────────────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v kubectl >/dev/null || die "kubectl not found"
command -v argocd  >/dev/null || die "argocd CLI not found — brew install argocd"

kubectl config use-context "$CONTEXT" 2>/dev/null || \
  die "kubectl context '$CONTEXT' not found — run 'make cluster-up' first"

kubectl cluster-info --context "$CONTEXT" >/dev/null 2>&1 || \
  die "Cluster not reachable — is the kind cluster running?"
ok "Cluster reachable: $CONTEXT"

# ── 1. Install Argo CD ────────────────────────────────────────────────────────
info "Creating namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
ok "Namespace argocd exists"

info "Applying Argo CD manifests (version: ${ARGOCD_VERSION})..."
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl apply -n argocd -f "$MANIFEST_URL"
ok "Argo CD manifests applied"

info "Waiting for argocd-server to be Available (timeout: 5 min)..."
kubectl -n argocd wait deployment argocd-server \
  --for=condition=Available --timeout=300s
ok "argocd-server is Available"

# ── 2. Port-forward in background (needed for argocd CLI) ─────────────────────
info "Starting background port-forward argocd-server :8080→:443..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
kubectl -n argocd port-forward svc/argocd-server 8080:443 \
  --context "$CONTEXT" >/dev/null 2>&1 &
PF_PID=$!
sleep 4  # give port-forward time to establish

# ── 3. Login and change admin password ───────────────────────────────────────
info "Retrieving initial admin password..."
INITIAL_PASS=$(argocd admin initial-password -n argocd 2>/dev/null | head -1 | tr -d '\n')
[[ -z "$INITIAL_PASS" ]] && die "Could not retrieve initial admin password"

info "Logging in as admin..."
argocd login localhost:8080 \
  --username admin \
  --password "$INITIAL_PASS" \
  --insecure >/dev/null 2>&1

info "Updating admin password..."
argocd account update-password \
  --current-password "$INITIAL_PASS" \
  --new-password "$ARGOCD_PASSWORD" >/dev/null 2>&1
ok "Admin password set"

# Delete the bootstrap secret (security hygiene)
kubectl -n argocd delete secret argocd-initial-admin-secret 2>/dev/null || true
ok "Bootstrap secret deleted"

# ── 4. Re-login with new password ─────────────────────────────────────────────
argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure >/dev/null 2>&1
ok "Re-logged in with new admin password"

# ── 5. Register the GitOps repository ────────────────────────────────────────
info "Registering repo: $REPO_URL"
argocd repo add "$REPO_URL" \
  --name devops-learning \
  --type git >/dev/null 2>&1 || \
  info "Repo may already be registered — continuing"
ok "Repository registered"

# ── 6. Patch reconciliation interval for faster demos ─────────────────────────
info "Patching argocd-cm: timeout.reconciliation=30s (demo-friendly)..."
kubectl -n argocd patch cm argocd-cm \
  --type merge \
  --patch '{"data":{"timeout.reconciliation":"30s"}}' >/dev/null 2>&1
ok "Reconciliation interval: 30s"

# ── 7. Stop background port-forward ──────────────────────────────────────────
kill "$PF_PID" 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
ok "Argo CD bootstrap complete"
echo ""
echo "  UI:       https://localhost:8080  (after: make port-forward)"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo "  Repo:     $REPO_URL"
echo ""
echo "  Next steps:"
echo "    1. Edit infra/argocd/app-of-apps.yaml — set repoURL to your fork"
echo "    2. make sync"
echo "════════════════════════════════════════════════════════"
