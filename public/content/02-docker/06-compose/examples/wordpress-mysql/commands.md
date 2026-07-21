# wordpress-mysql — Commands

> Quick pickup reference. Pair with `../../README.md` for theory.

## Setup

```bash
# Move into this example
cd 02-docker/06-compose/examples/wordpress-mysql
```

## Core commands

```bash
# Bring up the WordPress + MySQL stack in the background
docker compose up -d
```

```bash
# Show service status (wait for db Healthy, wp Started)
docker compose ps
```

## Build / run examples

```bash
# Open the WordPress install wizard in a browser
open http://localhost:8000
```

## Inspection / verification

```bash
# Tail logs from the wp service
docker compose logs -f wp
```

## Cleanup

```bash
# Stop + remove containers, keep the named DB volume
docker compose down
```

```bash
# Stop + remove containers AND nuke the DB volume (data loss)
docker compose down -v
```

## One-liners worth memorising

```bash
# Validate the compose file before bringing it up
docker compose config
```
