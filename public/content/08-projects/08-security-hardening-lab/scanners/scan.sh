#!/usr/bin/env bash
# scanners/scan.sh
# ─────────────────────────────────────────────────────────────────────────────
# Image vulnerability scan using Trivy.
# Fails the pipeline on HIGH or CRITICAL findings.
# Called by: make scan
#
# Usage:
#   ./scanners/scan.sh IMAGE_REF [OUTPUT_JSON]
#   IMAGE_REF  — fully qualified image reference with digest
#                e.g. ghcr.io/org/app@sha256:a1b2c3...
#   OUTPUT_JSON — optional path to write JSON report (default: scan-results.json)
#
# EDUCATIONAL DEFENSIVE SECURITY ONLY
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
IMAGE_REF="${1:-}"
OUTPUT_JSON="${2:-scan-results.json}"
TRIVY_CONFIG="$(dirname "$0")/trivy-config.yaml"
EXIT_CODE=0

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$IMAGE_REF" ]]; then
  echo "[ERROR] Usage: $0 IMAGE_REF [OUTPUT_JSON]"
  echo "[ERROR] Example: $0 ghcr.io/org/app@sha256:a1b2c3..."
  exit 1
fi

if ! command -v trivy &>/dev/null; then
  echo "[ERROR] trivy not found. Install: https://aquasecurity.github.io/trivy/"
  exit 1
fi

echo "════════════════════════════════════════════════════════"
echo " Trivy Image Scan"
echo " Image:  ${IMAGE_REF}"
echo " Config: ${TRIVY_CONFIG}"
echo "════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Vulnerability scan (table output for readability) ─────────────────
echo "[1/3] Running vulnerability scan..."
trivy image \
  --config "${TRIVY_CONFIG}" \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --format table \
  "${IMAGE_REF}" || EXIT_CODE=$?

# ── Step 2: Secret scan ───────────────────────────────────────────────────────
echo ""
echo "[2/3] Running secret scan..."
trivy image \
  --scanners secret \
  --exit-code 1 \
  --format table \
  "${IMAGE_REF}" || {
    echo "[ERROR] Secrets found in image layers. Remove them from the build."
    EXIT_CODE=1
  }

# ── Step 3: Write JSON report for CI artifact storage ─────────────────────────
echo ""
echo "[3/3] Writing JSON report to ${OUTPUT_JSON}..."
trivy image \
  --config "${TRIVY_CONFIG}" \
  --format json \
  --output "${OUTPUT_JSON}" \
  "${IMAGE_REF}" 2>/dev/null || true   # JSON write failure is non-fatal

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo " SCAN RESULT: PASS — no HIGH or CRITICAL vulnerabilities"
  echo " Report saved to: ${OUTPUT_JSON}"
else
  echo " SCAN RESULT: FAIL — HIGH or CRITICAL vulnerabilities found"
  echo " Review ${OUTPUT_JSON} and either:"
  echo "   1. Update the base image to a patched version"
  echo "   2. Add a documented .trivyignore entry with justification"
  echo "   3. Use a distroless base image (gcr.io/distroless/static)"
fi
echo "════════════════════════════════════════════════════════"

exit "$EXIT_CODE"
