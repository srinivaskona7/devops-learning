# 03-distroless — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Move into the example
cd 02-docker/03-images-and-dockerfile/examples/03-distroless
```

## Core commands

```bash
# Build the distroless Node image
docker build -t distroless-hello:1.0 .
```

## Build / run examples

```bash
# Run, publish port 8080
docker run --rm -p 8080:8080 distroless-hello:1.0
```

```bash
# Verify it serves
curl localhost:8080
```

## Inspection / verification

```bash
# Prove there's no shell: this exec WILL fail
docker run -d --name dl distroless-hello:1.0
docker exec -it dl sh
```

```bash
# Confirm runtime user is non-root (uid 65532)
docker inspect distroless-hello:1.0 | jq '.[0].Config.User'
```

```bash
# Compare size against a vanilla node:20 image
docker images | grep -E 'distroless-hello|node'
```

## Cleanup

```bash
# Remove container + image
docker rm -f dl
docker rmi distroless-hello:1.0
```

## One-liners worth memorising

```bash
# Health-check distroless apps via HTTP probe — no curl/wget inside
curl -fsS localhost:8080/healthz || echo unhealthy
```
