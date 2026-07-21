# Cosign — Sign and Verify Images

[Sigstore cosign](https://github.com/sigstore/cosign) provides image signing. Two modes:

1. **Key-based** — you hold a private key (RSA / ECDSA / ed25519)
2. **Keyless (recommended)** — OIDC identity (GitHub Actions, Google, etc.) → ephemeral cert from Fulcio CA → signature logged in Rekor transparency log

Keyless eliminates key management. The proof is the OIDC identity + the Rekor log entry.

## Install

```bash
brew install cosign
# or download from github.com/sigstore/cosign/releases
```

## Keyless signing in GitHub Actions

```yaml
# .github/workflows/release.yaml
permissions:
  id-token: write   # required for OIDC
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: sigstore/cosign-installer@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build & push
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
      - name: Sign
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          IMG=ghcr.io/${{ github.repository }}:${{ github.sha }}
          DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $IMG)
          cosign sign --yes $DIGEST
```

The signature lands in the registry as `sha256-<digest>.sig` next to the image. Provenance is in Rekor (`rekor.sigstore.dev`).

## Verify locally

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/myorg/myapp/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/myorg/myapp@sha256:abc...
```

The cert identity proves **which workflow signed it** — not just that *someone* signed it.

## Verify in admission (Kyverno)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["production"]
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/myapp/.github/workflows/release.yaml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
```

## Key-based (legacy / air-gapped)

```bash
cosign generate-key-pair                          # cosign.key + cosign.pub
cosign sign --key cosign.key registry/img@sha256:...
cosign verify --key cosign.pub registry/img@sha256:...
```

## Attestations (signed metadata)

Sign **statements** about an image — SBOMs, vuln scans, SLSA provenance.

```bash
# Attach an SBOM as a signed attestation
syft ghcr.io/myorg/app:1.2.3 -o spdx-json > sbom.json
cosign attest --predicate sbom.json --type spdxjson ghcr.io/myorg/app@sha256:...

# Verify an attestation
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp "https://github.com/myorg/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/myorg/app@sha256:...
```
