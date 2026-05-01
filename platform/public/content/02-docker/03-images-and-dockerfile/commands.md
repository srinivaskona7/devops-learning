# Images and Dockerfile — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm BuildKit-capable docker is present
docker version
```

```bash
# Move into the example you'll build
cd examples/01-basic
```

## Core commands

```bash
# Build an image from the Dockerfile in cwd, tag it
docker build -t myapp:1.0 .
```

```bash
# Re-tag an existing local image for a different name/registry
docker tag myapp:1.0 ghcr.io/me/myapp:1.0
```

```bash
# Run an image (overrides CMD if you append args)
docker run --rm myapp:1.0
```

```bash
# Override the ENTRYPOINT for ad-hoc debugging
docker run --rm --entrypoint sh myapp:1.0
```

## Build / run examples

```bash
# Build the basic Flask example
docker build -t flask-hello:1.0 .
```

```bash
# Run it, publish port 5000
docker run --rm -p 5000:5000 flask-hello:1.0
```

```bash
# Verify it serves
curl localhost:5000
```

## Inspection / verification

```bash
# Show the image with size
docker images flask-hello
```

```bash
# Show layer-by-layer instruction history (great for spotting bloat)
docker history flask-hello:1.0
```

```bash
# Inspect full image config (entrypoint, env, user, exposed ports)
docker inspect flask-hello:1.0
```

```bash
# Lint a Dockerfile with hadolint (run as a container)
docker run --rm -i hadolint/hadolint < Dockerfile
```

## Cleanup

```bash
# Remove an image by tag
docker rmi flask-hello:1.0
```

```bash
# Remove every dangling image left behind by re-builds
docker image prune
```

## One-liners worth memorising

```bash
# Pin a base image by digest for reproducible builds
# FROM python@sha256:abc123...   (put in Dockerfile, not shell)
docker buildx imagetools inspect python:3.12-slim | grep Digest
```

```bash
# Build with a specific build-time arg
docker build --build-arg PY_VERSION=3.12.6 -t myapp:1.0 .
```

```bash
# Build without using the cache (forces every layer to re-run)
docker build --no-cache -t myapp:1.0 .
```

```bash
# Show only the layer sizes for an image, biggest waste first
docker history --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" flask-hello:1.0
```
