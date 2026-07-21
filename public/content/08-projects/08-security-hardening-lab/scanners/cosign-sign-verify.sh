#!/usr/bin/env bash
# scanners/cosign-sign-verify.sh
# ─────────────────────────────────────────────────────────────────────────────
# Keyless image signing with cosign (Sigstore) and signature verification.
# Uses Fulcio as the CA and Rekor as the transparency log.
# No private keys are stored anywhere — identity comes from OIDC (CI/workload).
#
# Usage:
#   SIGN:   ./cosign-sign-verify.sh sign   IMAGE_REF
#   VERIFY: ./cosign-sign-verify.sh verify IMAGE_REF ISSUER_REGEX SUBJECT_REGEX
#
# EDUCATIONAL DEFENSIVE SECURITY ONLY
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
REKOR_URL="${REKOR_URL:-https://rekor.sigstore.dev}"
FULCIO_URL="${FULCIO_URL:-https://fulcio.sigstore.dev}"

# Expected OIDC issuer for verification (GitHub Actions default)
# Override these environment variables in your CI configuration
DEFAULT_OIDC_ISSUER="${OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
# Expected subject pattern: the workflow that is allowed to sign
# Example: "https://github.com/org/repo/.github/workflows/build.yaml@refs/heads/main"
DEFAULT_SUBJECT_REGEX="${SUBJECT_REGEX:-^https://github.com/}"

ACTION="${1:-}"
IMAGE_REF="${2:-}"

# ── Validation ─────────────────────────────────────────────────────────────────
if [[ -z "$ACTION" || -z "$IMAGE_REF" ]]; then
  echo "[ERROR] Usage:"
  echo "  $0 sign   IMAGE_REF"
  echo "  $0 verify IMAGE_REF [ISSUER_REGEX] [SUBJECT_REGEX]"
  exit 1
fi

if ! command -v cosign &>/dev/null; then
  echo "[ERROR] cosign not found."
  echo "  Install: https://docs.sigstore.dev/cosign/installation/"
  exit 1
fi

# IMAGE_REF must contain a digest (enforced by require-image-digest Kyverno policy)
if [[ "$IMAGE_REF" != *"@sha256:"* ]]; then
  echo "[ERROR] IMAGE_REF must include a sha256 digest, e.g.:"
  echo "  ghcr.io/org/app@sha256:a1b2c3..."
  echo "  A tag-only reference is not acceptable for signing."
  exit 1
fi

# ── Sign ───────────────────────────────────────────────────────────────────────
sign() {
  echo "════════════════════════════════════════════════════════"
  echo " cosign keyless SIGN"
  echo " Image:   ${IMAGE_REF}"
  echo " Fulcio:  ${FULCIO_URL}"
  echo " Rekor:   ${REKOR_URL}"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "[INFO] OIDC identity will be obtained from the CI environment."
  echo "[INFO] Supported: GitHub Actions, GitLab CI, Google WIF, Kubernetes OIDC."
  echo ""

  # COSIGN_EXPERIMENTAL=1 enables keyless flow with Rekor transparency log
  COSIGN_EXPERIMENTAL=1 cosign sign \
    --yes \
    --fulcio-url="${FULCIO_URL}" \
    --rekor-url="${REKOR_URL}" \
    "${IMAGE_REF}"

  echo ""
  echo "[SUCCESS] Image signed. Signature recorded in Rekor transparency log:"
  echo "  ${REKOR_URL}"
  echo ""
  echo "[NEXT] Verify the signature before deploying:"
  echo "  $0 verify ${IMAGE_REF}"
}

# ── Verify ────────────────────────────────────────────────────────────────────
verify() {
  local issuer_regex="${3:-$DEFAULT_OIDC_ISSUER}"
  local subject_regex="${4:-$DEFAULT_SUBJECT_REGEX}"

  echo "════════════════════════════════════════════════════════"
  echo " cosign keyless VERIFY"
  echo " Image:          ${IMAGE_REF}"
  echo " Rekor:          ${REKOR_URL}"
  echo " OIDC Issuer:    ${issuer_regex}"
  echo " Subject regex:  ${subject_regex}"
  echo "════════════════════════════════════════════════════════"
  echo ""

  # Verify that:
  # 1. A valid signature exists for this exact digest
  # 2. The signature was issued by the expected OIDC provider
  # 3. The subject (workflow identity) matches the expected pattern
  COSIGN_EXPERIMENTAL=1 cosign verify \
    --rekor-url="${REKOR_URL}" \
    --certificate-identity-regexp="${subject_regex}" \
    --certificate-oidc-issuer="${issuer_regex}" \
    "${IMAGE_REF}" | jq '.[0] | {
      "verified": true,
      "image_digest": .critical.image."docker-manifest-digest",
      "signed_by": .optional.Subject,
      "issuer": .optional.Issuer,
      "build_trigger": .optional."github-workflow-ref"
    }'

  echo ""
  echo "[SUCCESS] Signature verified against Rekor transparency log."
  echo "[INFO] This image was built by a trusted CI identity, not tampered."
}

# ── Policy enforcement verification ──────────────────────────────────────────
# Additional step: verify the SBOM attestation is present (used by Kyverno
# or OPA Gatekeeper for policy enforcement at admission time)
verify_attestation() {
  echo ""
  echo "[INFO] Checking for CycloneDX SBOM attestation..."
  COSIGN_EXPERIMENTAL=1 cosign verify-attestation \
    --rekor-url="${REKOR_URL}" \
    --type cyclonedx \
    --certificate-identity-regexp="${DEFAULT_SUBJECT_REGEX}" \
    --certificate-oidc-issuer="${DEFAULT_OIDC_ISSUER}" \
    "${IMAGE_REF}" | jq '.payload | @base64d | fromjson | {
      "predicate_type": .predicateType,
      "component_count": (.predicate.components | length),
      "sbom_version": .predicate.version
    }'
  echo "[SUCCESS] CycloneDX SBOM attestation present and verified."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$ACTION" in
  sign)
    sign
    ;;
  verify)
    verify "$@"
    ;;
  verify-all)
    verify "$@"
    verify_attestation
    ;;
  *)
    echo "[ERROR] Unknown action: $ACTION. Use: sign | verify | verify-all"
    exit 1
    ;;
esac
