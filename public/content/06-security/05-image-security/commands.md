# Image Security — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Trivy
brew install aquasecurity/trivy/trivy
trivy --version

# Cosign + syft (Sigstore + SBOM)
brew install cosign syft
cosign version
syft version

# Buildx for multi-arch
docker buildx create --use --name multiarch
```

## Apply policies / manifests

```bash
# Multi-arch, multi-stage, non-root, pinned base — push to registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/org/myapp:1.2.3 --push .

# Sign image keylessly (OIDC — GitHub/Google identity)
cosign sign ghcr.io/org/myapp:1.2.3

# Generate SBOM and attach as attestation
syft ghcr.io/org/myapp:1.2.3 -o spdx-json > sbom.spdx.json
cosign attest --predicate sbom.spdx.json \
  --type spdxjson ghcr.io/org/myapp:1.2.3
```

## Inspect / verify

```bash
# Scan an image for CVEs (fail build on HIGH/CRITICAL)
trivy image --severity HIGH,CRITICAL --exit-code 1 ghcr.io/org/myapp:1.2.3

# Filesystem scan during build
trivy fs --severity HIGH,CRITICAL ./

# IaC / misconfig scan (Dockerfile, K8s manifests, Terraform)
trivy config ./Dockerfile
trivy config --severity HIGH ./manifests/

# Live cluster scan (running images)
trivy k8s --report summary cluster

# Verify signature
cosign verify ghcr.io/org/myapp:1.2.3 \
  --certificate-identity-regexp 'https://github.com/org/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Verify attestation
cosign verify-attestation --type spdxjson ghcr.io/org/myapp:1.2.3 \
  --certificate-identity-regexp 'https://github.com/org/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Inspect SBOM contents
syft ghcr.io/org/myapp:1.2.3 -o table
```

## Common operations

```bash
# Pin to digest, not tag — copy from your registry
docker pull ghcr.io/org/myapp:1.2.3
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/org/myapp:1.2.3
# Use the @sha256:... value in your manifests

# Generate VEX (which CVEs are NOT exploitable)
trivy image --format cyclonedx ghcr.io/org/myapp:1.2.3 > sbom.cdx.json
# author VEX statements separately, attach via cosign attest

# Reproducible build timestamp
SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct) docker buildx build ...
```

## Cleanup

```bash
# Local cache
docker buildx prune -af
docker image prune -af
trivy image --clear-cache

# Registry signature/attestation cleanup happens via registry CLI
# (e.g. ghcr/oras delete) — out of scope for cosign
```

## One-liners worth memorising

```bash
# Quick sweep of every running image in a cluster for criticals
for img in $(kubectl get pods -A -o jsonpath='{..image}' | tr -s ' ' '\n' | sort -u); do
  trivy image --severity CRITICAL --quiet "$img"
done

# Find any pod still on :latest
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | grep ':latest'

# One-shot scan + sign + attest in CI
trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMG" && \
  cosign sign "$IMG" && \
  syft "$IMG" -o spdx-json | cosign attest --predicate - --type spdxjson "$IMG"
```
