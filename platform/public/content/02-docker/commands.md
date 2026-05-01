# Docker · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."
> Every command is safe to run on a live host unless marked ⚠️.

---

## Pane 1 — triage (first 60 seconds)

```bash
# What's running and how healthy is it?
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# CPU / memory at a glance (one shot, no stream)
docker stats --no-stream --format \
  "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Tail last 200 lines of a container's logs
docker logs --tail 200 -f <container>

# Show exit code + restart count + OOM kill flag
docker inspect <container> --format \
  '{{.State.ExitCode}} restarts={{.RestartCount}} oom={{.State.OOMKilled}}'

# Disk usage overview — see what's reclaimable
docker system df

# Show disk usage by image (verbose)
docker system df -v | head -40
```

---

## Pane 2 — diagnose (go deeper)

```bash
# Full JSON dump — env, mounts, network, health history
docker inspect <container> | jq '.[0] | {
  Env: .Config.Env,
  Mounts: .Mounts,
  Ports: .NetworkSettings.Ports,
  Health: .State.Health,
  State: .State
}'

# What has the container written / changed vs its image?
docker diff <container>
# A = added, C = changed, D = deleted — 'A /usr/bin/backdoor' is suspicious

# Copy a file OUT of a container (works even when stopped)
docker cp <container>:/path/to/file /tmp/

# Enter a running container (needs shell in image)
docker exec -it <container> /bin/sh

# Enter container namespaces using HOST tools (works on distroless!)
PID=$(docker inspect -f '{{.State.Pid}}' <container>)
sudo nsenter -t $PID -m -u -i -n -p -- /bin/sh

# Check network connectivity from inside a container
docker exec <container> wget -qO- http://otherservice:8080/health

# Inspect environment variables of a running container
docker exec <container> env

# Show all open ports / listening sockets (if ss/netstat available)
docker exec <container> ss -tlnp

# Inspect a specific volume mount path
docker inspect <container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}\n{{end}}'

# Show layer diff for an image (requires dive — brew install dive)
dive <image>
```

---

## Pane 3 — images & builds

```bash
# List images with size, sorted by size descending
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h -r

# Show image layers and their sizes
docker history <image> --human --format "table {{.CreatedBy}}\t{{.Size}}"

# Inspect an image's config (ENTRYPOINT, CMD, ENV, USER)
docker inspect <image> --format '{{json .Config}}' | jq '{
  User: .User,
  Entrypoint: .Entrypoint,
  Cmd: .Cmd,
  Env: .Env
}'

# Get the content digest of a local image (use this in K8s manifests)
docker inspect --format='{{index .RepoDigests 0}}' <image>

# Build with BuildKit + cache mount (fast pip / npm / apt)
DOCKER_BUILDKIT=1 docker build -t myapp:latest .

# Multi-arch build and push in one command
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myregistry/myapp:latest \
  --push .

# Build targeting a specific stage (e.g., builder only)
docker build --target builder -t myapp:builder .

# Build with a secret (never baked into layers)
docker buildx build \
  --secret id=gh_token,src=$HOME/.gh_token \
  --tag myapp:latest .

# See all buildx builders
docker buildx ls

# Create a multi-arch builder
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

---

## Pane 4 — registry operations

```bash
# Login to Docker Hub
docker login

# Login to GHCR (GitHub Container Registry)
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin

# Login to a private registry
docker login myregistry.example.com

# Tag and push
docker tag myapp:latest myregistry.example.com/myteam/myapp:v1.2.3
docker push myregistry.example.com/myteam/myapp:v1.2.3

# Pull by digest (immutable — use in prod deploys)
docker pull myregistry.example.com/myteam/myapp@sha256:<digest>

# Inspect a manifest list (multi-arch index)
docker buildx imagetools inspect myregistry.example.com/myteam/myapp:latest

# Run a local registry
docker run -d -p 5000:5000 --name registry registry:2

# List tags in a local registry
curl -s http://localhost:5000/v2/<name>/tags/list | jq .

# Get manifest digest from a registry
curl -sI \
  -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
  http://localhost:5000/v2/<name>/manifests/<tag> \
  | grep docker-content-digest
```

---

## Pane 5 — networking

```bash
# List networks
docker network ls

# Create a user-defined bridge (enables embedded DNS)
docker network create mynet

# Connect a running container to a network
docker network connect mynet <container>

# Disconnect a container from a network
docker network disconnect mynet <container>

# Inspect a network — see connected containers and their IPs
docker network inspect mynet --format '{{json .Containers}}' | jq .

# Test DNS resolution between containers on same user-defined network
docker exec <container1> ping -c 2 <container2-name>

# Show iptables NAT rules Docker created (host-level, requires root)
sudo iptables -t nat -L DOCKER --line-numbers

# Remove all unused networks
docker network prune -f
```

---

## Pane 6 — volumes & storage

```bash
# Create a named volume
docker volume create mydata

# Inspect volume (see host mount point)
docker volume inspect mydata --format '{{.Mountpoint}}'

# List volumes and their sizes (requires driver support)
docker system df -v | grep -A 100 'Local Volumes'

# Run with a named volume
docker run -v mydata:/data alpine ls /data

# Run with a tmpfs (in-memory, never written to disk)
docker run --tmpfs /tmp:rw,size=64m,mode=1777 alpine df -h /tmp

# Run with read-only root filesystem + tmpfs for writable dirs
docker run --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run \
  myapp:latest

# Backup a volume to a tar archive
docker run --rm \
  -v mydata:/source:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/mydata-backup.tar.gz -C /source .

# Restore a volume from a tar archive
docker run --rm \
  -v mydata:/target \
  -v $(pwd):/backup:ro \
  alpine sh -c "tar xzf /backup/mydata-backup.tar.gz -C /target"

# List dangling volumes (not attached to any container)
docker volume ls -f dangling=true

# ⚠️ Remove a specific volume (data is gone)
docker volume rm mydata

# ⚠️ Remove all unused volumes
docker volume prune -f
```

---

## Pane 7 — security

```bash
# Check what USER the container runs as
docker exec <container> whoami
docker inspect <container> --format '{{.Config.User}}'

# Check security options (seccomp, apparmor, no-new-privileges)
docker inspect <container> --format '{{.HostConfig.SecurityOpt}}'

# Run with no new privileges (prevents setuid escalation)
docker run --security-opt no-new-privileges:true myapp:latest

# Run with a custom seccomp profile
docker run --security-opt seccomp=/path/to/profile.json myapp:latest

# Drop all capabilities and add back only what's needed
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx:alpine

# Show capabilities of a running container
docker inspect <container> --format '{{.HostConfig.CapAdd}} / {{.HostConfig.CapDrop}}'

# Scan image with trivy (install: brew install trivy)
trivy image --severity CRITICAL,HIGH <image>

# Scan and fail CI on CRITICAL CVEs
trivy image --exit-code 1 --severity CRITICAL <image>

# Generate an SBOM (Software Bill of Materials)
trivy image --format cyclonedx --output sbom.json <image>

# Sign an image with cosign (keyless OIDC)
cosign sign --yes <registry>/<image>@<digest>

# Verify an image signature
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp ".*" \
  <registry>/<image>@<digest>
```

---

## Pane 8 — observability

```bash
# Live stats stream for all containers
docker stats

# One-shot stats with custom format
docker stats --no-stream --format \
  "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

# Stream all container lifecycle events
docker events --filter type=container \
  --format '{{.Time}} {{.Actor.Attributes.name}} {{.Action}}'

# Filter for OOM kills only
docker events --filter type=container --filter event=oom

# Filter events for a specific container
docker events --filter container=<name>

# Follow logs with timestamps
docker logs -f --timestamps <container>

# Show logs between two timestamps
docker logs --since "2026-04-27T02:00:00" --until "2026-04-27T03:00:00" <container>

# Run cAdvisor (exposes Prometheus metrics for all containers)
docker run -d \
  --name cadvisor \
  --volume /:/rootfs:ro \
  --volume /var/run:/var/run:ro \
  --volume /sys:/sys:ro \
  --volume /var/lib/docker/:/var/lib/docker:ro \
  --publish 8080:8080 \
  gcr.io/cadvisor/cadvisor:latest

# Query a cAdvisor metric
curl -s http://localhost:8080/metrics \
  | grep 'container_cpu_usage_seconds_total{' \
  | grep -v '^#'
```

---

## Pane 9 — Docker Compose

```bash
# Start the stack (detached)
docker compose up -d

# Start with a specific profile
docker compose --profile debug up -d

# Show status of all services
docker compose ps

# Follow logs for all services
docker compose logs -f

# Follow logs for a specific service
docker compose logs -f web

# Execute a command in a running service container
docker compose exec web /bin/sh

# Restart a single service
docker compose restart web

# Rebuild and recreate a service without downtime for others
docker compose up -d --build web

# Scale a service to N replicas
docker compose up -d --scale worker=3

# Stop and remove containers + networks (keeps volumes)
docker compose down

# ⚠️ Stop and remove containers + networks + volumes
docker compose down -v

# Validate compose file without running it
docker compose config

# Watch source files and sync changes into containers (Compose 2.22+)
docker compose watch
```

---

## Pane 10 — cleanup (staged, safe to run in order)

```bash
# 1. See what's reclaimable before touching anything
docker system df

# 2. Remove exited / stopped containers
docker container prune -f

# 3. Remove dangling images (<none>:<none>)
docker image prune -f

# 4. Remove unused networks
docker network prune -f

# 5. Remove build cache older than 7 days
docker builder prune --filter until=168h -f

# 6. Remove ALL unused images (not just dangling) ⚠️
docker image prune -a -f

# 7. Remove dangling volumes ⚠️ (check first!)
docker volume ls -f dangling=true
docker volume prune -f

# Nuclear option: everything unused in one command ⚠️
docker system prune -f --volumes

# Safe nightly cron: remove cache/containers/networks older than 7d,
# keep all images that are in use
docker system prune -f --filter until=168h
```

---

## Reference: flag cheat sheet

| Flag | Command | Effect |
|------|---------|--------|
| `--rm` | `docker run` | Remove container on exit |
| `-d` | `docker run` | Detached (background) |
| `-it` | `docker run` | Interactive + TTY |
| `--name` | `docker run` | Name the container |
| `-p HOST:CONTAINER` | `docker run` | Publish port |
| `-v NAME:PATH` | `docker run` | Mount named volume |
| `-v /host:PATH` | `docker run` | Bind mount |
| `--tmpfs PATH` | `docker run` | In-memory tmpfs |
| `--read-only` | `docker run` | Read-only root filesystem |
| `--cap-drop=ALL` | `docker run` | Drop all Linux capabilities |
| `--security-opt no-new-privileges:true` | `docker run` | Block setuid escalation |
| `--memory=256m` | `docker run` | Hard memory limit |
| `--cpus=0.5` | `docker run` | CPU limit (0.5 = 50% of one core) |
| `--network` | `docker run` | Attach to a specific network |
| `--platform` | `docker buildx build` | Target architecture |
| `--push` | `docker buildx build` | Push to registry after build |
| `--secret` | `docker buildx build` | Inject build secret (no layer) |
| `--target` | `docker build` | Stop at a named stage |
| `--no-cache` | `docker build` | Force full rebuild |
