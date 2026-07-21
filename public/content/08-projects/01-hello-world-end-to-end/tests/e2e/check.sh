#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Project 01 · Hello World on Docker — E2E check script
#
# Usage:
#   bash tests/e2e/check.sh [BASE_URL] [CONTAINER_NAME]
#
# Defaults:
#   BASE_URL        = http://localhost:8080
#   CONTAINER_NAME  = hello
#
# What this checks:
#   1. HTTP 200 on GET /
#   2. X-Frame-Options: DENY header present
#   3. X-Content-Type-Options: nosniff header present
#   4. Content-Security-Policy header present
#   5. Server header does NOT expose nginx version
#   6. CSS file returns 200 with text/css content-type
#   7. Container process runs as non-root UID (not 0)
#   8. Read-only rootfs: write to / is refused
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
BASE_URL="${1:-http://localhost:8080}"
CONTAINER="${2:-hello}"

PASS=0
FAIL=0

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

pass() { printf "  ${GREEN}✔${RESET} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ${RED}✖${RESET} %s\n" "$1"; FAIL=$((FAIL + 1)); }
info() { printf "\n${CYAN}▸${RESET} %s\n" "$1"; }

# ── Check helpers ─────────────────────────────────────────────────────────────

# Fetch headers once and reuse (avoid hammering the server with identical requests)
HEADERS=$(curl -sI --max-time 5 "${BASE_URL}/") || {
  printf "${RED}ERROR:${RESET} Could not connect to %s\n" "${BASE_URL}"
  printf "Make sure the container is running: make run\n"
  exit 1
}

# ── Check 1: HTTP 200 ─────────────────────────────────────────────────────────
info "Check 1 — HTTP 200 on GET /"
STATUS=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "${BASE_URL}/")
if [ "${STATUS}" = "200" ]; then
  pass "GET / → ${STATUS} OK"
else
  fail "GET / → ${STATUS}  (expected 200)"
fi

# ── Check 2: X-Frame-Options ─────────────────────────────────────────────────
info "Check 2 — X-Frame-Options: DENY"
if echo "${HEADERS}" | grep -qi "x-frame-options: deny"; then
  pass "X-Frame-Options: DENY present"
else
  fail "X-Frame-Options: DENY missing (clickjacking protection not active)"
fi

# ── Check 3: X-Content-Type-Options ──────────────────────────────────────────
info "Check 3 — X-Content-Type-Options: nosniff"
if echo "${HEADERS}" | grep -qi "x-content-type-options: nosniff"; then
  pass "X-Content-Type-Options: nosniff present"
else
  fail "X-Content-Type-Options: nosniff missing"
fi

# ── Check 4: Content-Security-Policy ─────────────────────────────────────────
info "Check 4 — Content-Security-Policy present"
if echo "${HEADERS}" | grep -qi "content-security-policy:"; then
  pass "Content-Security-Policy header present"
else
  fail "Content-Security-Policy header missing"
fi

# ── Check 5: Server header does not expose nginx version ─────────────────────
info "Check 5 — Server header does not expose nginx version"
SERVER_HEADER=$(echo "${HEADERS}" | grep -i "^server:" || echo "")
if echo "${SERVER_HEADER}" | grep -qiE "nginx/[0-9]"; then
  fail "Server header leaks version: ${SERVER_HEADER}  (server_tokens must be off)"
else
  pass "Server header does not contain nginx version string"
fi

# ── Check 6: CSS file returns 200 with text/css ───────────────────────────────
info "Check 6 — styles.css → 200 with text/css content-type"
CSS_STATUS=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "${BASE_URL}/styles.css")
CSS_TYPE=$(curl -sI --max-time 5 "${BASE_URL}/styles.css" | grep -i "content-type:" || echo "")
if [ "${CSS_STATUS}" = "200" ] && echo "${CSS_TYPE}" | grep -qi "text/css"; then
  pass "styles.css → 200 · text/css"
else
  fail "styles.css → status=${CSS_STATUS}, content-type=${CSS_TYPE}"
fi

# ── Check 7: Non-root UID ─────────────────────────────────────────────────────
info "Check 7 — container process runs as non-root (UID ≠ 0)"
if ! docker inspect "${CONTAINER}" --format='{{.State.Running}}' 2>/dev/null | grep -q "true"; then
  fail "Container '${CONTAINER}' is not running — skipping UID check"
else
  UID_LINE=$(docker exec "${CONTAINER}" id 2>&1)
  if echo "${UID_LINE}" | grep -q "uid=0"; then
    fail "Process running as root: ${UID_LINE}"
  else
    pass "Non-root: ${UID_LINE}"
  fi
fi

# ── Check 8: Read-only rootfs ─────────────────────────────────────────────────
info "Check 8 — read-only rootfs (write to / must fail)"
if ! docker inspect "${CONTAINER}" --format='{{.State.Running}}' 2>/dev/null | grep -q "true"; then
  fail "Container '${CONTAINER}' is not running — skipping rootfs check"
else
  WRITE_RESULT=$(docker exec "${CONTAINER}" sh -c 'touch /rw-probe 2>&1; echo "exit:$?"')
  if echo "${WRITE_RESULT}" | grep -q "exit:0"; then
    fail "Write to / succeeded — container is NOT running with --read-only"
  else
    pass "Write to / refused (read-only rootfs confirmed)"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n──────────────────────────────────────────\n"
printf "Results: ${GREEN}${PASS} passed${RESET}  ${RED}${FAIL} failed${RESET}\n"
printf "──────────────────────────────────────────\n\n"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
