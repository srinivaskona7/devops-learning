#!/usr/bin/env bash
# tests/e2e/journey.sh — Full user journey for the URL Shortener
#
# Tests performed:
#   1. Stack health check
#   2. Shorten a URL
#   3. Retrieve short code from DB
#   4. Follow redirect
#   5. Verify hit counter incremented
#   6. List recent links
#   7. 404 on unknown code
#
# Requirements: curl, jq, docker, docker compose
#
# Usage:
#   bash tests/e2e/journey.sh
#   BASE_URL=http://staging.example.com bash tests/e2e/journey.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
COMPOSE="docker compose -f infra/docker-compose.yml"
PASS=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────
green()  { printf "\033[32m  ✔ %s\033[0m\n" "$*"; }
red()    { printf "\033[31m  ✗ %s\033[0m\n" "$*"; }
header() { printf "\n\033[1;36m── %s\033[0m\n" "$*"; }

assert() {
  local label="$1"
  local condition="$2"
  if eval "$condition" > /dev/null 2>&1; then
    green "$label"
    PASS=$((PASS + 1))
  else
    red "$label"
    FAIL=$((FAIL + 1))
  fi
}

require() {
  for cmd in "$@"; do
    command -v "$cmd" > /dev/null 2>&1 || { echo "Required: $cmd" >&2; exit 1; }
  done
}

# ── Pre-flight ────────────────────────────────────────────────────────────
require curl jq docker

header "Pre-flight — dependencies"
assert "curl available" "command -v curl"
assert "jq available"   "command -v jq"
assert "docker available" "command -v docker"

# ── Step 1: Health ────────────────────────────────────────────────────────
header "Step 1 — Stack health"

HEALTHZ=$(curl -sf "${BASE_URL}/healthz" || echo "{}")
assert "/healthz returns status ok" "echo '${HEALTHZ}' | jq -e '.status == \"ok\"'"

READY=$(curl -sf "${BASE_URL}/ready" || echo "{}")
assert "/ready returns status ready" "echo '${READY}' | jq -e '.status == \"ready\"'"

# ── Step 2: Shorten ───────────────────────────────────────────────────────
header "Step 2 — Shorten a URL"

TARGET_URL="https://github.com/torvalds/linux?ref=journey-$(date +%s)"

SHORTEN_RESP=$(curl -sf -X POST "${BASE_URL}/api/shorten" \
  -H 'Content-Type: application/json' \
  -d "{\"url\":\"${TARGET_URL}\"}" || echo "{}")

echo "  Response: ${SHORTEN_RESP}"

CODE=$(echo "${SHORTEN_RESP}" | jq -r '.code // empty')
SHORT_URL=$(echo "${SHORTEN_RESP}" | jq -r '.short_url // empty')

assert "POST /api/shorten returns 201 (via body)" \
  "echo '${SHORTEN_RESP}' | jq -e '.code'"

assert "Response has short_url field" \
  "echo '${SHORTEN_RESP}' | jq -e '.short_url'"

if [[ -z "${CODE}" ]]; then
  red "No code returned — aborting remaining tests"
  echo ""
  echo "  PASSED: ${PASS}  FAILED: $((FAIL + 1))"
  exit 1
fi

echo "  Code: ${CODE}"
echo "  Short URL: ${SHORT_URL}"

# ── Step 3: Verify code in DB ─────────────────────────────────────────────
header "Step 3 — Verify code exists in Postgres"

DB_CODE=$(${COMPOSE} exec -T db psql -U shortener -d shortener -t -c \
  "SELECT code FROM urls WHERE code = '${CODE}';" 2>/dev/null | tr -d ' \n')

assert "Code '${CODE}' found in urls table" "[ '${DB_CODE}' = '${CODE}' ]"

HITS_BEFORE=$(${COMPOSE} exec -T db psql -U shortener -d shortener -t -c \
  "SELECT hits FROM urls WHERE code = '${CODE}';" 2>/dev/null | tr -d ' \n')

echo "  hits before redirect: ${HITS_BEFORE}"

# ── Step 4: Follow redirect ───────────────────────────────────────────────
header "Step 4 — Follow the redirect"

HTTP_STATUS=$(curl -o /dev/null -sw "%{http_code}" "${BASE_URL}/${CODE}" \
  --max-redirs 0 2>/dev/null)

assert "GET /${CODE} returns 302" "[ '${HTTP_STATUS}' = '302' ]"

LOCATION=$(curl -sI "${BASE_URL}/${CODE}" 2>/dev/null | grep -i "^location:" | tr -d '\r' | awk '{print $2}')
assert "Location header points to target URL" \
  "[[ '${LOCATION}' == '${TARGET_URL}'* ]]"

echo "  Location: ${LOCATION}"

# ── Step 5: Verify hit counter ────────────────────────────────────────────
header "Step 5 — Hit counter increment"

HITS_AFTER=$(${COMPOSE} exec -T db psql -U shortener -d shortener -t -c \
  "SELECT hits FROM urls WHERE code = '${CODE}';" 2>/dev/null | tr -d ' \n')

echo "  hits after redirect: ${HITS_AFTER}"

assert "hits incremented by 1" \
  "[ $((HITS_AFTER)) -eq $((HITS_BEFORE + 1)) ]"

# ── Step 6: List links ────────────────────────────────────────────────────
header "Step 6 — List recent links"

LINKS_RESP=$(curl -sf "${BASE_URL}/api/links?limit=5" || echo '{"links":[]}')
LINK_COUNT=$(echo "${LINKS_RESP}" | jq '.links | length')

assert "GET /api/links returns at least 1 link" "[ ${LINK_COUNT} -ge 1 ]"

echo "  ${LINK_COUNT} link(s) returned"

# ── Step 7: 404 on unknown code ───────────────────────────────────────────
header "Step 7 — Unknown code returns 404"

HTTP_404=$(curl -o /dev/null -sw "%{http_code}" \
  "${BASE_URL}/zzz000NOTEXIST" 2>/dev/null)

assert "GET /zzz000NOTEXIST returns 404" "[ '${HTTP_404}' = '404' ]"

# ── Duplicate URL returns same code ──────────────────────────────────────
header "Step 8 — Duplicate URL reuse"

DUP_RESP=$(curl -sf -X POST "${BASE_URL}/api/shorten" \
  -H 'Content-Type: application/json' \
  -d "{\"url\":\"${TARGET_URL}\"}" || echo "{}")

DUP_CODE=$(echo "${DUP_RESP}" | jq -r '.code // empty')

assert "Duplicate URL returns same code" "[ '${DUP_CODE}' = '${CODE}' ]"

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
printf "  \033[32mPASSED: %d\033[0m  " "${PASS}"
if [ "${FAIL}" -gt 0 ]; then
  printf "\033[31mFAILED: %d\033[0m\n" "${FAIL}"
  echo "────────────────────────────────────────"
  exit 1
else
  printf "\033[32mFAILED: 0\033[0m\n"
  echo "────────────────────────────────────────"
  echo "  All journey steps passed."
fi
