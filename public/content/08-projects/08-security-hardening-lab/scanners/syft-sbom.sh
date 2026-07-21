#!/usr/bin/env bash
# scanners/syft-sbom.sh
# ─────────────────────────────────────────────────────────────────────────────
# Generate a CycloneDX SBOM with syft and upload it as a cosign attestation.
# The attestation anchors the SBOM to the image digest in the Rekor transparency
# log — making it discoverable and verifiable without a central SBOM store.
#
# Usage:
#   ./syft-sbom.sh IMAGE_REF [OUTPUT_FILE]
#   IMAGE_REF   — e.g. ghcr.io/org/app@sha256:a1b2c3...
#   OUTPUT_FILE — optional output path (default: sbom-cyclonedx.json)
#
# EDUCATIONAL DEFENSIVE SECURITY ONLY
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
IMAGE_REF="${1:-}"
OUTPUT_FILE="${2:-sbom-cyclonedx.json}"
REKOR_URL="${REKOR_URL:-https://rekor.sigstore.dev}"
FULCIO_URL="${FULCIO_URL:-https://fulcio.sigstore.dev}"

DEFAULT_OIDC_ISSUER="${OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
DEFAULT_SUBJECT_REGEX="${SUBJECT_REGEX:-^https://github.com/}"

# ── Validation ─────────────────────────────────────────────────────────────────
if [[ -z "$IMAGE_REF" ]]; then
  echo "[ERROR] Usage: $0 IMAGE_REF [OUTPUT_FILE]"
  exit 1
fi

if [[ "$IMAGE_REF" != *"@sha256:"* ]]; then
  echo "[ERROR] IMAGE_REF must contain a sha256 digest."
  echo "  Example: ghcr.io/org/app@sha256:a1b2c3..."
  exit 1
fi

for cmd in syft cosign jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[ERROR] $cmd not found."
    case "$cmd" in
      syft)   echo "  Install: https://github.com/anchore/syft#installation" ;;
      cosign) echo "  Install: https://docs.sigstore.dev/cosign/installation/" ;;
      jq)     echo "  Install: brew install jq  OR  apt install jq" ;;
    esac
    exit 1
  fi
done

echo "════════════════════════════════════════════════════════"
echo " SBOM Generation + Attestation"
echo " Image:  ${IMAGE_REF}"
echo " Output: ${OUTPUT_FILE}"
echo "════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Generate CycloneDX SBOM ───────────────────────────────────────────
echo "[1/4] Generating CycloneDX SBOM with syft..."
syft "${IMAGE_REF}" \
  --output cyclonedx-json="${OUTPUT_FILE}" \
  --scope all-layers \
  --quiet

# Print component summary
COMPONENT_COUNT=$(jq '.components | length' "${OUTPUT_FILE}")
echo "[INFO] SBOM generated: ${COMPONENT_COUNT} components catalogued"
echo "[INFO] Output: ${OUTPUT_FILE}"

# ── Step 2: Print top-level metadata ─────────────────────────────────────────
echo ""
echo "[2/4] SBOM metadata summary:"
jq '{
  "spec_version": .specVersion,
  "serial_number": .serialNumber,
  "component_count": (.components | length),
  "metadata_component": .metadata.component.name,
  "metadata_version": .metadata.component.version
}' "${OUTPUT_FILE}"

# ── Step 3: Upload SBOM as cosign attestation ─────────────────────────────────
echo ""
echo "[3/4] Attaching SBOM to image as cosign attestation..."
echo "[INFO] Attestation will be recorded in Rekor transparency log."
echo "[INFO] OIDC identity from CI environment will be used for signing."
echo ""

COSIGN_EXPERIMENTAL=1 cosign attest \
  --yes \
  --predicate "${OUTPUT_FILE}" \
  --type cyclonedx \
  --fulcio-url="${FULCIO_URL}" \
  --rekor-url="${REKOR_URL}" \
  "${IMAGE_REF}"

# ── Step 4: Verify the attestation was recorded ───────────────────────────────
echo ""
echo "[4/4] Verifying attestation in Rekor..."
COSIGN_EXPERIMENTAL=1 cosign verify-attestation \
  --type cyclonedx \
  --rekor-url="${REKOR_URL}" \
  --certificate-identity-regexp="${DEFAULT_SUBJECT_REGEX}" \
  --certificate-oidc-issuer="${DEFAULT_OIDC_ISSUER}" \
  "${IMAGE_REF}" \
  | jq '.[0].payload | @base64d | fromjson | {
      "predicate_type": .predicateType,
      "component_count": (.predicate.components | length),
      "signed_at": .metadata.buildFinishedOn
    }'

echo ""
echo "════════════════════════════════════════════════════════"
echo " SBOM ATTESTATION: COMPLETE"
echo ""
echo " The SBOM is now:"
echo "   1. Stored as a cosign attestation on the OCI registry"
echo "   2. Anchored to the image digest in the Rekor transparency log"
echo "   3. Verifiable by Kyverno or OPA at admission time"
echo ""
echo " To verify later:"
echo "   cosign verify-attestation --type cyclonedx ${IMAGE_REF}"
echo "════════════════════════════════════════════════════════"
