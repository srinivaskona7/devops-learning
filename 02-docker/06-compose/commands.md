# Compose — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm Compose v2 ships with your engine (note the SPACE)
docker compose version
```

## Core commands

```bash
# Validate + render the final merged compose file
docker compose config
```

```bash
# Create + start the whole stack in the background
docker compose up -d
```

```bash
# Show service status
docker compose ps
```

```bash
# Tail logs of one service
docker compose logs -f web
```

```bash
# Shell into a running service
docker compose exec web sh
```

```bash
# Restart a single service
docker compose restart web
```

```bash
# Stop and remove containers + the project network (keeps named volumes)
docker compose down
```

```bash
# Same, but ALSO delete named volumes — destroys data
docker compose down -v
```

```bash
# Pull updated images for all services
docker compose pull
```

```bash
# Build local Dockerfiles referenced by services
docker compose build
```

## Build / run examples

```bash
# WordPress + MySQL stack
cd examples/wordpress-mysql
docker compose up -d
```

```bash
# Open the WP install wizard
open http://localhost:8000
```

```bash
# Prometheus + Grafana stack
cd examples/observability
docker compose up -d
open http://localhost:9090
open http://localhost:3000
```

## Inspection / verification

```bash
# See the merged config including overrides
docker compose -f compose.yaml -f compose.prod.yaml config
```

```bash
# Wait until "db" reports healthy before continuing
docker compose ps db
```

## Cleanup

```bash
# Tear down keeping volumes
docker compose down
```

```bash
# Tear down AND drop volumes
docker compose down -v
```

## One-liners worth memorising

```bash
# Bring up only services in a named profile
docker compose --profile debug up
```

```bash
# Use multiple compose files (base + prod overrides)
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

```bash
# One-shot exec without leaving the container running
docker compose run --rm web sh
```
