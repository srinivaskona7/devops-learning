# BuildKit and buildx — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Force-enable BuildKit on older Docker versions
export DOCKER_BUILDKIT=1
```

```bash
# Confirm buildx version
docker buildx version
```

```bash
# List available builders + supported platforms
docker buildx ls
```

## Core commands

```bash
# Create a new builder instance and use it (bootstraps QEMU emulators)
docker buildx create --name multi --use --bootstrap
```

```bash
# Switch back to the default builder
docker buildx use default
```

```bash
# Remove a builder
docker buildx rm multi
```

## Build / run examples

```bash
# Build for both amd64 and arm64, push the manifest list to a registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/me/myapp:1.0 \
  --push \
  .
```

```bash
# Single-platform build that loads into the local docker engine
docker buildx build --platform linux/amd64 -t go-hello:1.0 --load .
```

```bash
# Build using a secret env var (mounted only during one RUN)
docker buildx build --secret id=ghtoken,env=GH_TOKEN -t myimg .
```

```bash
# Build using forwarded SSH agent (clone private git repos in the build)
docker buildx build --ssh default -t myimg .
```

```bash
# Push + pull build cache through a registry (best for CI)
docker buildx build \
  --cache-to   type=registry,ref=ghcr.io/me/myapp:cache,mode=max \
  --cache-from type=registry,ref=ghcr.io/me/myapp:cache \
  -t ghcr.io/me/myapp:1.0 \
  --push .
```

```bash
# Inline cache stored inside the image itself (simpler, less powerful)
docker buildx build \
  --cache-to   type=inline \
  --cache-from ghcr.io/me/myapp:1.0 \
  -t ghcr.io/me/myapp:1.0 \
  --push .
```

```bash
# Export build output as a local filesystem (no image)
docker buildx build -o type=local,dest=./out .
```

```bash
# Export as a docker tarball
docker buildx build -o type=tar,dest=./image.tar .
```

```bash
# Export as an OCI image tarball
docker buildx build -o type=oci,dest=./oci.tar .
```

## Inspection / verification

```bash
# Inspect a multi-arch image manifest list
docker buildx imagetools inspect ghcr.io/me/myapp:1.0
```

```bash
# See what platforms a builder supports
docker buildx inspect --bootstrap
```

## Cleanup

```bash
# Drop the multi-arch builder
docker buildx rm multi
```

```bash
# Prune builder cache (be careful — kills warm caches)
docker buildx prune
```

## One-liners worth memorising

```bash
# Remember: --load and --push are mutually exclusive
# --load works only for single-platform builds
docker buildx build --platform linux/amd64 -t myapp:1.0 --load .
```

```bash
# # syntax=docker/dockerfile:1.7   <-- MUST be first line of Dockerfile
# Enables cache mounts, secret mounts, and SSH mounts
echo '# syntax=docker/dockerfile:1.7'
```
