# Production Patterns — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm engine + buildx are recent enough for provenance/sbom
docker version
docker buildx version
```

## Core commands

```bash
# Run with Docker's built-in init (handles zombies + signal forwarding)
docker run --init myimg
```

```bash
# Run with explicit resource limits — never run without them in prod
docker run \
  --memory 512m \
  --memory-swap 512m \
  --cpus 1.0 \
  --pids-limit 200 \
  myimg
```

```bash
# Restart policy — survive daemon restarts, respect manual stops
docker run --restart unless-stopped myimg
```

```bash
# Send SIGTERM and wait 30s before SIGKILL (give app time to drain)
docker stop --time 30 mycontainer
```

```bash
# Pass config via env, secrets via mounted file
docker run \
  -e DATABASE_URL=postgres://... \
  -e LOG_LEVEL=info \
  --secret source=db-password,target=/run/secrets/db-password \
  myimg
```

## Build / run examples

```bash
# Build the production-ready template (multi-stage, nonroot, healthcheck)
docker build -t myapp:prod .
```

```bash
# Run it with all the safety flags
docker run -d --name app \
  --init \
  --restart unless-stopped \
  --memory 512m --cpus 1.0 \
  --read-only --tmpfs /tmp \
  -e LOG_LEVEL=info \
  -p 8080:8080 \
  myapp:prod
```

## Inspection / verification

```bash
# Show running container health status
docker ps
```

```bash
# Tail logs (logs come from stdout/stderr, never from files)
docker logs -f app
```

```bash
# Inspect the configured healthcheck and last results
docker inspect --format '{{json .State.Health}}' app | jq .
```

```bash
# Check effective resource limits applied
docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' app
```

```bash
# Verify STOPSIGNAL (some apps want SIGQUIT, not SIGTERM)
docker inspect --format '{{.Config.StopSignal}}' app
```

## Cleanup

```bash
# Graceful stop with extended grace window
docker stop --time 30 app
```

```bash
# Remove the container
docker rm app
```

## One-liners worth memorising

```bash
# Configure a remote logging driver (compose example in README)
docker run --log-driver=gelf --log-opt gelf-address=udp://logstash:12201 myimg
```

```bash
# Build with provenance + SBOM attestations (supply chain hardening)
docker buildx build --provenance=true --sbom=true -t myapp:prod --push .
```

```bash
# Reproducible cold rebuild for release
docker build --no-cache --pull -t myapp:prod .
```

```bash
# Quick health probe of a running app from the host
curl -fsS http://localhost:8080/healthz && echo OK || echo FAIL
```
