# 01-basic — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Make sure you're in this example dir
cd 02-docker/03-images-and-dockerfile/examples/01-basic
```

## Core commands

```bash
# Build the Flask image with this folder's Dockerfile
docker build -t flask-hello:1.0 .
```

## Build / run examples

```bash
# Run the container, publish port 5000, auto-remove on exit
docker run --rm -p 5000:5000 flask-hello:1.0
```

```bash
# Hit the app
curl localhost:5000
```

## Inspection / verification

```bash
# Confirm size (~125 MB)
docker images flask-hello:1.0
```

```bash
# View layer-by-layer build history
docker history flask-hello:1.0
```

```bash
# Confirm the configured non-root user
docker inspect flask-hello:1.0 | jq '.[0].Config.User'
```

```bash
# Watch healthcheck status flip to (healthy) after ~30s
docker ps
```

## Cleanup

```bash
# Remove the image when done
docker rmi flask-hello:1.0
```

## One-liners worth memorising

```bash
# Rebuild after editing app.py — only the bottom layers re-run
docker build -t flask-hello:1.0 .
```
