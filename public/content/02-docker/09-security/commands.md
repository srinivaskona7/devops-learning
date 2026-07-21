# Security — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Install Trivy (vulnerability scanner)
brew install trivy
```

```bash
# Install Grype (alternate scanner)
brew install grype
```

```bash
# Install cosign (Sigstore signing)
brew install cosign
```

## Core commands

```bash
# Run as a specific UID:GID instead of root
docker run --user 1000:1000 myimg
```

```bash
# Run with a read-only root filesystem (writes go to mounted tmpfs)
docker run \
  --read-only \
  --tmpfs /tmp:size=64m \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  myimg
```

```bash
# Scan an image for HIGH/CRITICAL CVEs
trivy image --severity HIGH,CRITICAL myapp:1.0
```

```bash
# CI gate: fail the build if any CRITICAL CVEs found
trivy image --exit-code 1 --severity CRITICAL myapp:1.0
```

```bash
# Alternate scan with grype
grype myapp:1.0
```

## Build / run examples

```bash
# Generate a cosign keypair (or use OIDC keyless in CI)
cosign generate-key-pair
```

```bash
# Sign an image with the key
cosign sign --key cosign.key ghcr.io/me/myapp:1.0
```

```bash
# Verify signature
cosign verify --key cosign.pub ghcr.io/me/myapp:1.0
```

```bash
# Keyless sign in CI (uses Fulcio + Rekor via OIDC)
cosign sign ghcr.io/me/myapp:1.0
```

```bash
# Build with a secret mounted only during a single RUN
DOCKER_BUILDKIT=1 docker build \
  --secret id=npmrc,src=$HOME/.npmrc \
  -t myapp .
```

```bash
# Generate an SBOM as part of the build
docker buildx build --sbom=true -t myapp:1.0 .
```

```bash
# Extract the embedded SBOM
docker buildx imagetools inspect myapp:1.0 --format '{{ json .SBOM }}'
```

```bash
# Generate SBOM with syft
syft myapp:1.0 -o spdx-json > sbom.json
```

```bash
# Hardened run: nonroot, read-only, dropped caps, resource limits
docker run -d --name hardened \
  --user 65532:65532 \
  --read-only \
  --tmpfs /tmp:size=32m \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory 128m --cpus 0.5 \
  --pids-limit 100 \
  -p 8080:8080 \
  gcr.io/distroless/static-debian12:nonroot \
  /myapp
```

## Inspection / verification

```bash
# Confirm a running container is non-root
docker exec hardened id
```

```bash
# Show the image's effective USER
docker inspect myapp:1.0 | jq '.[0].Config.User'
```

```bash
# Check `docker history` for accidental secrets in build args/env
docker history --no-trunc myapp:1.0 | grep -iE 'token|key|secret|password'
```

## Cleanup

```bash
# Stop + remove the hardened container
docker rm -f hardened
```

## One-liners worth memorising

```bash
# Never do this in prod — full host compromise
# docker run --privileged ...
# docker run -v /var/run/docker.sock:/var/run/docker.sock ...
echo "AVOID --privileged and bind-mounting /var/run/docker.sock"
```

```bash
# Pin base image by digest (paste into Dockerfile FROM)
docker buildx imagetools inspect python:3.12-slim | grep -i digest
```
