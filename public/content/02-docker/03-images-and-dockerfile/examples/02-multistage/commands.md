# 02-multistage — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Move into this example
cd 02-docker/03-images-and-dockerfile/examples/02-multistage
```

## Core commands

```bash
# Build the multi-stage Go image (toolchain stays in the build stage)
docker build -t go-hello:1.0 .
```

## Build / run examples

```bash
# Run, publish port 8080
docker run --rm -p 8080:8080 go-hello:1.0
```

```bash
# Hit it
curl localhost:8080
```

## Inspection / verification

```bash
# Confirm ~7 MB final image (vs ~350 MB single-stage)
docker images go-hello:1.0
```

```bash
# See that runtime stage is FROM scratch — only ca-certs + binary
docker history go-hello:1.0
```

## Cleanup

```bash
# Remove the image
docker rmi go-hello:1.0
```

## One-liners worth memorising

```bash
# Build a single named stage (useful for debugging the build stage)
docker build --target build -t go-hello:build .
```
