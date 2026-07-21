# Image Optimization — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm BuildKit is on (default since Docker 23, force on older)
export DOCKER_BUILDKIT=1
```

## Core commands

```bash
# Build the naive version, tag it for comparison
docker build -t myapp:v1-naive .
```

```bash
# Build the optimized (multi-stage) version
docker build -t myapp:v2-slim -f Dockerfile.slim .
```

```bash
# Build a distroless variant
docker build -t myapp:v3-distroless -f Dockerfile.distroless .
```

## Build / run examples

```bash
# Build with a BuildKit cache mount for pip (cache survives across builds)
docker build -t myapp:cached .
```

```bash
# Run any of the variants to confirm they still work
docker run --rm -p 8080:8080 myapp:v3-distroless
```

## Inspection / verification

```bash
# Compare image sizes side-by-side
docker images myapp
```

```bash
# Per-layer size breakdown — find the bloated instructions
docker history myapp:v3-distroless --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}"
```

```bash
# dive: TUI showing wasted space + efficiency score
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest myapp:1.0
```

```bash
# Confirm .dockerignore is being respected — context size in build output
docker build -t myapp:1.0 . 2>&1 | grep -i 'transferring context'
```

## Cleanup

```bash
# Remove the comparison images
docker rmi myapp:v1-naive myapp:v2-slim myapp:v3-distroless
```

```bash
# Drop dangling layers left behind by iterative builds
docker image prune
```

## One-liners worth memorising

```bash
# Force a clean build (no cache) — confirms cold-build size + time
docker build --no-cache -t myapp:cold .
```

```bash
# Build only up to a named stage (debug a multi-stage Dockerfile)
docker build --target build -t myapp:builder .
```

```bash
# Pull a slimmer base and re-tag — quick win on legacy images
docker pull python:3.12-slim
```

```bash
# Show layers sorted by size to see biggest waste first
docker history myapp:1.0 --format "{{.Size}}\t{{.CreatedBy}}" | sort -h -r | head
```
