# observability — Commands

> Quick pickup reference. Pair with `../../README.md` for theory.

## Setup

```bash
# Move into this example
cd 02-docker/06-compose/examples/observability
```

## Core commands

```bash
# Bring up Prometheus + Grafana + node-exporter
docker compose up -d
```

```bash
# Show service status
docker compose ps
```

## Build / run examples

```bash
# Open Prometheus UI
open http://localhost:9090
```

```bash
# Open Grafana (default admin/admin)
open http://localhost:3000
```

## Inspection / verification

```bash
# Tail logs across all services
docker compose logs -f
```

```bash
# Check Prometheus is scraping targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

## Cleanup

```bash
# Stop + remove containers AND volumes (Grafana state goes too)
docker compose down -v
```

## One-liners worth memorising

```bash
# Validate the compose file
docker compose config
```
