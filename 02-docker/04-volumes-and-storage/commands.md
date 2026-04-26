# Volumes and Storage — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm docker is up
docker version
```

## Core commands

```bash
# Create a named volume (managed by Docker)
docker volume create pgdata
```

```bash
# List all volumes
docker volume ls
```

```bash
# Inspect a volume — shows the host mountpoint
docker volume inspect pgdata
```

```bash
# Delete a named volume (must not be in use)
docker volume rm pgdata
```

## Build / run examples

```bash
# Bind-mount cwd into the container at /app, drop into a shell
docker run --rm -it -v "$PWD":/app -w /app node:20-alpine sh
```

```bash
# Same, using the explicit --mount syntax
docker run --rm -it --mount type=bind,source="$PWD",target=/app -w /app node:20-alpine sh
```

```bash
# Run postgres with a named volume for its data dir
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

```bash
# Use a tmpfs (RAM-backed) mount, sized 64 MB
docker run --rm -it --tmpfs /scratch:size=64m alpine sh
```

```bash
# Read-only bind mount (config file)
docker run --rm -v "$PWD/config.yaml":/etc/app/config.yaml:ro alpine cat /etc/app/config.yaml
```

```bash
# Write to a named volume from one container
docker run --rm -v mydata:/data alpine sh -c 'echo "persistent!" > /data/file.txt'
```

```bash
# Read it back from another container — proves persistence
docker run --rm -v mydata:/data alpine cat /data/file.txt
```

## Inspection / verification

```bash
# Find the actual host path backing a named volume
docker volume inspect mydata | jq -r '.[0].Mountpoint'
```

```bash
# Backup a volume to a tarball on the host
docker run --rm \
  -v mydata:/source:ro \
  -v "$PWD":/backup \
  alpine tar czf /backup/mydata.tar.gz -C /source .
```

```bash
# Restore a tarball into a fresh volume
docker volume create newdata
docker run --rm \
  -v newdata:/target \
  -v "$PWD":/backup:ro \
  alpine tar xzf /backup/mydata.tar.gz -C /target
```

```bash
# Create a volume backed by NFS (driver opts)
docker volume create --driver local \
  --opt type=nfs \
  --opt o=addr=10.0.0.1,rw \
  --opt device=:/exported/path \
  nfs-vol
```

## Cleanup

```bash
# Delete unused volumes
docker volume prune
```

```bash
# Force-remove a container AND its anonymous volumes (named ones survive)
docker rm -fv <container>
```

## One-liners worth memorising

```bash
# Run as host UID/GID so files written from container are owned correctly
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/app alpine touch /app/hello
```

```bash
# Quickly confirm a volume's contents without writing host files
docker run --rm -v mydata:/data alpine ls -lah /data
```
