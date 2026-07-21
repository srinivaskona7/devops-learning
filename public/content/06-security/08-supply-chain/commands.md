# Supply Chain Security — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Sigstore tools
brew install cosign syft
cosign version

# slsa-verifier (verify SLSA provenance locally)
brew install slsa-verifier

# in-toto attestation framework (optional CLI)
go install github.com/in-toto/in-toto-golang/cmd/in-toto@latest
```

## Apply policies / manifests

```bash
# Use the SLSA reusable GitHub Actions workflow in CI
# .github/workflows/release.yaml — see github-actions-slsa.yaml in this folder

# Kyverno policy: only allow images signed by your CI identity
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: verify-signed-images }
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signature
      match: { any: [{ resources: { kinds: [Pod] } }] }
      verifyImages:
        - imageReferences: ["ghcr.io/org/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/org/repo/.github/workflows/release.yaml@refs/tags/*"
                    issuer: "https://token.actions.githubusercontent.com"
EOF

# Sigstore policy-controller alternative
helm install policy-controller sigstore/policy-controller -n cosign-system --create-namespace
```

## Inspect / verify

```bash
# Verify SLSA provenance on a built artifact
slsa-verifier verify-image ghcr.io/org/myapp:1.2.3 \
  --source-uri github.com/org/repo \
  --source-tag v1.2.3

# Verify cosign signature, pinning to workflow identity
cosign verify ghcr.io/org/myapp:1.2.3 \
  --certificate-identity 'https://github.com/org/repo/.github/workflows/release.yaml@refs/tags/v1.2.3' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Inspect attached attestations (provenance, SBOM, VEX)
cosign tree ghcr.io/org/myapp:1.2.3
cosign download attestation ghcr.io/org/myapp:1.2.3 \
  | jq -r '.payload' | base64 -d | jq .

# Search Rekor transparency log for an artifact
cosign verify --rekor-url https://rekor.sigstore.dev ghcr.io/org/myapp:1.2.3

# Verify a signed git commit
git log --show-signature -1
git verify-commit HEAD
```

## Common operations

```bash
# Generate provenance locally (for non-GitHub builds)
cosign attest --predicate provenance.json \
  --type slsaprovenance ghcr.io/org/myapp:1.2.3

# Attach SBOM as attestation
syft ghcr.io/org/myapp:1.2.3 -o spdx-json > sbom.json
cosign attest --predicate sbom.json --type spdxjson ghcr.io/org/myapp:1.2.3

# Sign a git commit / tag
git commit -S -m "release: 1.2.3"
git tag -s v1.2.3 -m "1.2.3"

# Pin a GitHub Action by SHA, not tag (provenance hardening)
# uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

## Cleanup

```bash
kubectl delete clusterpolicy verify-signed-images
helm uninstall policy-controller -n cosign-system
rm -f provenance.json sbom.json *.sig *.cert
```

## One-liners worth memorising

```bash
# What was attached to this image?
cosign tree ghcr.io/org/myapp:1.2.3

# Verify any image — pinned to org-wide workflow regex
cosign verify ghcr.io/org/myapp@sha256:... \
  --certificate-identity-regexp 'https://github.com/org/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Reject unsigned images cluster-wide (Kyverno verifyImages above) — in dry-run first:
kubectl patch clusterpolicy verify-signed-images --type=merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'

# Pull a Rekor entry by UUID
rekor-cli get --uuid <uuid>
```
