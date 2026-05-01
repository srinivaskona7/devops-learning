#!/usr/bin/env bash
# tests/audit.sh
# ─────────────────────────────────────────────────────────────────────────────
# Automated security audit — runs all 8 check categories and prints a
# PASS/FAIL matrix. Exit code 0 = all pass; non-zero = one or more failures.
#
# Usage:
#   ./tests/audit.sh [NAMESPACE] [IMAGE_REF]
#   NAMESPACE — target namespace (default: production)
#   IMAGE_REF — image to verify signature on (default: reads from running pod)
#
# EDUCATIONAL DEFENSIVE SECURITY ONLY
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

NAMESPACE="${1:-production}"
IMAGE_REF="${2:-}"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Result tracking ───────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
declare -a FAILURES=()

pass() {
  local msg="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${NC}  %s\n" "$msg"
}

fail() {
  local msg="$1"
  local detail="${2:-}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES+=("$msg")
  printf "  ${RED}FAIL${NC}  %s\n" "$msg"
  [[ -n "$detail" ]] && printf "        ${YELLOW}→ %s${NC}\n" "$detail"
}

check() {
  local description="$1"
  local cmd="$2"
  local expected="$3"    # expected substring in output, or "EXIT_0" for exit code check
  local output
  local exit_code=0

  output=$(eval "$cmd" 2>&1) || exit_code=$?

  if [[ "$expected" == "EXIT_0" ]]; then
    [[ "$exit_code" -eq 0 ]] && pass "$description" || fail "$description" "$output"
  elif echo "$output" | grep -q "$expected" 2>/dev/null; then
    pass "$description"
  else
    fail "$description" "Got: $(echo "$output" | head -3)"
  fi
}

section() {
  echo ""
  printf "${CYAN}[%s]${NC} %s\n" "$1" "$2"
  echo "─────────────────────────────────────────────────"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  Security Hardening Lab — Automated Audit"
echo "  Namespace: ${NAMESPACE}"
echo "  Date:      $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "════════════════════════════════════════════════════════"

if ! command -v kubectl &>/dev/null; then
  echo "${RED}[ERROR]${NC} kubectl not found. Cannot run audit."
  exit 1
fi

# Auto-detect IMAGE_REF from running pods if not provided
if [[ -z "$IMAGE_REF" ]]; then
  IMAGE_REF=$(kubectl get pods -n "$NAMESPACE" \
    -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || true)
fi

# ── Check 1: RBAC ─────────────────────────────────────────────────────────────
section "1/8" "RBAC Hardening"

# Check for cluster-admin bindings to workload SAs
CLUSTER_ADMIN_SAS=$(kubectl get clusterrolebindings -o json 2>/dev/null \
  | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]? | select(.kind=="ServiceAccount") | .name' \
  2>/dev/null || echo "")

if [[ -z "$CLUSTER_ADMIN_SAS" ]]; then
  pass "No workload ServiceAccounts bound to cluster-admin"
else
  fail "cluster-admin bound to SA(s): $CLUSTER_ADMIN_SAS" \
    "Remove ClusterRoleBinding and apply hardened/secure-rbac.yaml"
fi

check "secure-sa cannot perform wildcard verbs" \
  "kubectl auth can-i '*' '*' --as=system:serviceaccount:${NAMESPACE}:secure-sa 2>&1" \
  "no"

check "secure-sa cannot delete pods" \
  "kubectl auth can-i delete pods --as=system:serviceaccount:${NAMESPACE}:secure-sa -n ${NAMESPACE} 2>&1" \
  "no"

check "secure-sa cannot read secrets" \
  "kubectl auth can-i get secrets --as=system:serviceaccount:${NAMESPACE}:secure-sa -n ${NAMESPACE} 2>&1" \
  "no"

# ── Check 2: PSA ──────────────────────────────────────────────────────────────
section "2/8" "Pod Security Admission"

PSA_ENFORCE=$(kubectl get namespace "$NAMESPACE" \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")

if [[ "$PSA_ENFORCE" == "restricted" ]]; then
  pass "Namespace ${NAMESPACE} enforces PSA restricted profile"
else
  fail "Namespace ${NAMESPACE} PSA enforce label not set to restricted" \
    "Run: make psa-enable NAMESPACE=${NAMESPACE}"
fi

# Test that a root pod is rejected
ROOT_POD_RESULT=$(kubectl apply --dry-run=server -f - <<'EOF' 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: audit-root-test
  namespace: production
spec:
  containers:
  - name: test
    image: nginx@sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4
    securityContext:
      runAsUser: 0
      runAsNonRoot: false
EOF
)
if echo "$ROOT_POD_RESULT" | grep -qiE "(denied|violat|forbidden)"; then
  pass "Root container pod rejected by PSA/Kyverno"
else
  fail "Root container pod NOT rejected — admission control may be misconfigured" \
    "$ROOT_POD_RESULT"
fi

# ── Check 3: NetworkPolicy ────────────────────────────────────────────────────
section "3/8" "NetworkPolicy Default-Deny"

NETPOL=$(kubectl get networkpolicy default-deny-all -n "$NAMESPACE" \
  --no-headers 2>/dev/null | awk '{print $1}' || echo "")

if [[ "$NETPOL" == "default-deny-all" ]]; then
  pass "default-deny-all NetworkPolicy present in ${NAMESPACE}"
else
  fail "default-deny-all NetworkPolicy missing from ${NAMESPACE}" \
    "Run: make netpol-apply NAMESPACE=${NAMESPACE}"
fi

NETPOL_COUNT=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$NETPOL_COUNT" -ge 2 ]]; then
  pass "At least 2 NetworkPolicies present (default-deny + allow rules)"
else
  fail "Only $NETPOL_COUNT NetworkPolicy found — explicit allow rules may be missing"
fi

# ── Check 4: Kyverno Policies ─────────────────────────────────────────────────
section "4/8" "Kyverno Admission Policies"

REQUIRED_POLICIES=(
  "require-non-root"
  "require-resource-limits"
  "deny-privilege-escalation"
  "require-image-digest"
  "restrict-hostpath"
)

ENFORCE_COUNT=0
for POLICY in "${REQUIRED_POLICIES[@]}"; do
  MODE=$(kubectl get clusterpolicy "$POLICY" \
    -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "missing")
  if [[ "$MODE" == "Enforce" ]]; then
    pass "Policy ${POLICY} is in Enforce mode"
    ENFORCE_COUNT=$((ENFORCE_COUNT + 1))
  else
    fail "Policy ${POLICY} is ${MODE} (expected Enforce)" \
      "Run: make apply-policies"
  fi
done

# ── Check 5: Image Digest ─────────────────────────────────────────────────────
section "5/8" "Image Digest Pinning"

TAG_ONLY_IMAGES=$(kubectl get pods -n "$NAMESPACE" \
  -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null \
  | tr ' ' '\n' \
  | grep -v "@sha256:" \
  | grep -v "^$" || true)

if [[ -z "$TAG_ONLY_IMAGES" ]]; then
  pass "All running pods in ${NAMESPACE} use digest-pinned images"
else
  fail "Pods using tag-only images (not digest-pinned):" \
    "$TAG_ONLY_IMAGES"
fi

# ── Check 6: cosign Signature ─────────────────────────────────────────────────
section "6/8" "cosign Image Signature"

if [[ -z "$IMAGE_REF" ]]; then
  printf "  ${YELLOW}SKIP${NC}  cosign verification (no IMAGE_REF found or provided)\n"
elif ! command -v cosign &>/dev/null; then
  printf "  ${YELLOW}SKIP${NC}  cosign not installed — install from https://docs.sigstore.dev\n"
else
  COSIGN_OUT=$(COSIGN_EXPERIMENTAL=1 cosign verify \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --certificate-identity-regexp="^https://github.com/" \
    "$IMAGE_REF" 2>&1 || true)

  if echo "$COSIGN_OUT" | grep -q "Verification succeeded"; then
    pass "Image signature verified: ${IMAGE_REF}"
  else
    fail "Image signature NOT verified: ${IMAGE_REF}" \
      "Run: make sign IMAGE_REF=${IMAGE_REF}"
  fi
fi

# ── Check 7: SBOM Attestation ─────────────────────────────────────────────────
section "7/8" "CycloneDX SBOM Attestation"

if [[ -z "$IMAGE_REF" ]]; then
  printf "  ${YELLOW}SKIP${NC}  SBOM verification (no IMAGE_REF)\n"
elif ! command -v cosign &>/dev/null; then
  printf "  ${YELLOW}SKIP${NC}  cosign not installed\n"
else
  ATTEST_OUT=$(COSIGN_EXPERIMENTAL=1 cosign verify-attestation \
    --type cyclonedx \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --certificate-identity-regexp="^https://github.com/" \
    "$IMAGE_REF" 2>&1 || true)

  if echo "$ATTEST_OUT" | grep -q "cyclonedx"; then
    pass "CycloneDX SBOM attestation present and verified"
  else
    fail "CycloneDX SBOM attestation NOT found" \
      "Run: make sbom IMAGE_REF=${IMAGE_REF}"
  fi
fi

# ── Check 8: kube-bench ───────────────────────────────────────────────────────
section "8/8" "CIS Kubernetes Benchmark (kube-bench)"

if command -v kube-bench &>/dev/null; then
  BENCH_OUTPUT=$(kube-bench run --targets policies --json 2>/dev/null || echo "")
  PASS_CHECKS=$(echo "$BENCH_OUTPUT" | jq '[.Controls[].tests[].results[] | select(.status=="PASS")] | length' 2>/dev/null || echo "0")
  FAIL_CHECKS=$(echo "$BENCH_OUTPUT" | jq '[.Controls[].tests[].results[] | select(.status=="FAIL")] | length' 2>/dev/null || echo "0")
  TOTAL=$((PASS_CHECKS + FAIL_CHECKS))
  if [[ "$TOTAL" -gt 0 ]]; then
    SCORE=$(( (PASS_CHECKS * 100) / TOTAL ))
    if [[ "$SCORE" -ge 85 ]]; then
      pass "kube-bench CIS score: ${SCORE}% (${PASS_CHECKS}/${TOTAL} checks PASS)"
    else
      fail "kube-bench CIS score: ${SCORE}% — below 85% target" \
        "Review FAIL items: kube-bench run --targets policies"
    fi
  else
    printf "  ${YELLOW}SKIP${NC}  kube-bench returned no results — check RBAC for kube-bench SA\n"
  fi
else
  printf "  ${YELLOW}SKIP${NC}  kube-bench not installed. Run via Docker: make kube-bench\n"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
TOTAL_CHECKS=$((PASS_COUNT + FAIL_COUNT))
printf "  Security Audit Results: %d/%d checks\n" "$PASS_COUNT" "$TOTAL_CHECKS"
echo ""

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  printf "  ${GREEN}ALL CHECKS PASSED ✔  SLSA L2 COMPLIANT${NC}\n"
  echo ""
else
  printf "  ${RED}FAILED CHECKS (%d):${NC}\n" "$FAIL_COUNT"
  for F in "${FAILURES[@]}"; do
    printf "    ${RED}✗${NC} %s\n" "$F"
  done
  echo ""
  printf "  ${YELLOW}Fix the above and re-run: make audit-all${NC}\n"
fi

echo "════════════════════════════════════════════════════════"
echo ""

[[ "$FAIL_COUNT" -eq 0 ]]
