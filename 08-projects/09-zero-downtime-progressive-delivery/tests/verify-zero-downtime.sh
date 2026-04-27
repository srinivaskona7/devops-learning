#!/usr/bin/env bash
# tests/verify-zero-downtime.sh
# ─────────────────────────────────────────────────────────────────────────────
# Parse the k6 JSON summary produced by during-deploy.js and apply two
# zero-downtime pass criteria:
#
#   PASS if:  error_rate == 0.0000%  AND  p95 < 200 ms
#   FAIL otherwise — with a detailed breakdown of which threshold failed.
#
# Usage:
#   bash tests/verify-zero-downtime.sh                    # default path
#   bash tests/verify-zero-downtime.sh path/to/summary.json
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SUMMARY="${1:-tests/k6/results/summary.json}"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "${GREEN}  ✔ PASS${RESET}  $*"; }
fail() { echo -e "${RED}  ✗ FAIL${RESET}  $*"; }
info() { echo -e "${YELLOW}  ·${RESET}  $*"; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if [[ ! -f "${SUMMARY}" ]]; then
  echo -e "${RED}ERROR: k6 summary not found at ${SUMMARY}${RESET}"
  echo "       Run 'make load-during' first."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo -e "${RED}ERROR: jq is required (brew install jq / apt install jq)${RESET}"
  exit 1
fi

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Zero-Downtime Verification — Progressive Delivery        ${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
echo ""

# ── Extract metrics from JSON ─────────────────────────────────────────────────

# error_rate: fraction of failed HTTP requests (0 = perfect)
ERROR_RATE=$(jq -r '
  .metrics["http_req_failed"].values.rate // 0
' "${SUMMARY}")

# p95 latency in milliseconds
P95_MS=$(jq -r '
  .metrics["http_req_duration"].values["p(95)"] // 9999
' "${SUMMARY}")

# p99 latency in milliseconds (informational)
P99_MS=$(jq -r '
  .metrics["http_req_duration"].values["p(99)"] // 9999
' "${SUMMARY}")

# Total requests
TOTAL=$(jq -r '
  .metrics["http_reqs"].values.count // 0
' "${SUMMARY}")

# v1 / v2 split (custom counters)
V1=$(jq -r '
  .metrics["v1_requests_total"].values.count // 0
' "${SUMMARY}")

V2=$(jq -r '
  .metrics["v2_requests_total"].values.count // 0
' "${SUMMARY}")

# ── Display raw results ───────────────────────────────────────────────────────
echo -e "  ${BOLD}Metrics from: ${SUMMARY}${RESET}"
echo ""
info "Total requests : ${TOTAL}"
info "v1 responses   : ${V1}"
info "v2 responses   : ${V2}"
echo ""

# ── Apply thresholds ──────────────────────────────────────────────────────────
FAILURES=0

# Threshold 1: error rate must be exactly 0.
ERROR_PCT=$(echo "${ERROR_RATE} * 100" | bc -l 2>/dev/null || echo "0")
echo -e "  ${BOLD}[1] HTTP error rate${RESET}"
info "Measured : ${ERROR_PCT}%"
info "Target   : 0.0000%"
# Use awk for float comparison (bash can't do floats natively).
if awk "BEGIN{exit !( ${ERROR_RATE} == 0 )}"; then
  pass "error_rate=0.0000%"
else
  fail "error_rate=${ERROR_PCT}% — ABOVE zero threshold (any 5xx = rollback required)"
  FAILURES=$(( FAILURES + 1 ))
fi
echo ""

# Threshold 2: p95 latency < 200 ms.
echo -e "  ${BOLD}[2] p95 request latency${RESET}"
info "Measured : ${P95_MS}ms"
info "Target   : <200ms"
if awk "BEGIN{exit !( ${P95_MS} < 200 )}"; then
  pass "p95=${P95_MS}ms"
else
  fail "p95=${P95_MS}ms — ABOVE 200ms SLO"
  FAILURES=$(( FAILURES + 1 ))
fi
echo ""

# Informational: p99.
echo -e "  ${BOLD}[i] p99 latency (informational)${RESET}"
info "Measured : ${P99_MS}ms"
echo ""

# ── Final verdict ─────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
if [[ "${FAILURES}" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  RESULT: PASS — zero dropped requests, p95 within SLO   ${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}  RESULT: FAIL — ${FAILURES} threshold(s) breached           ${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
  echo ""
  echo "  Next steps:"
  echo "    1. Check rollout status:  kubectl argo rollouts get rollout demo-app-canary -n progressive"
  echo "    2. Trigger rollback:       make rollback"
  echo "    3. Review Prometheus:      http://localhost:9090/graph"
  exit 1
fi
