# Networking — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# List networks docker manages
docker network ls
```

## Core commands

```bash
# Create a user-defined bridge network (gets DNS between containers)
docker network create app-net
```

```bash
# Remove a network (no containers attached)
docker network rm app-net
```

```bash
# Inspect a network — subnet, gateway, attached containers
docker network inspect bridge
```

## Build / run examples

```bash
# Create network and run two services that resolve each other by name
docker network create demo-net
docker run -d --name web --network demo-net nginx:1.27-alpine
docker run --rm --network demo-net alpine \
  sh -c 'apk add --no-cache curl >/dev/null && curl -s http://web'
```

```bash
# Publish container port 80 to host 8080 (all interfaces)
docker run -d -p 8080:80 nginx
```

```bash
# Publish, but bind to localhost only — safer for dev
docker run -d -p 127.0.0.1:8080:80 nginx
```

```bash
# Publish a UDP port
docker run -d -p 8080:80/udp nginx
```

```bash
# Auto-assign random host ports for every EXPOSE in the image
docker run -d -P nginx
```

```bash
# Share the host's network stack (Linux only — no -p needed)
docker run --rm --network host nginx:1.27-alpine
```

```bash
# Disable networking entirely (loopback only)
docker run --rm --network none alpine ip a
```

## Inspection / verification

```bash
# Show the host port a container's port is mapped to
docker port <container>
```

```bash
# Reach the host from inside a container (Docker Desktop)
docker run --rm alpine ping -c1 host.docker.internal
```

```bash
# Resolve another container by name from inside the user network
docker run --rm --network demo-net alpine \
  sh -c 'apk add --no-cache bind-tools >/dev/null && nslookup web'
```

```bash
# Confirm DNS DOESN'T work on the default bridge
docker run -d --name web2 nginx:1.27-alpine
docker run --rm alpine \
  sh -c 'apk add --no-cache bind-tools >/dev/null && nslookup web2'
```

## Cleanup

```bash
# Force-remove containers + the user-defined network
docker rm -f web web2 || true
docker network rm demo-net
```

```bash
# Drop unused networks system-wide
docker network prune
```

## One-liners worth memorising

```bash
# Show every container's IP on every network
docker ps -q | xargs docker inspect --format '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
```

```bash
# Quick reachability test between two containers on a user network
docker run --rm --network demo-net nicolaka/netshoot curl -s http://web
```
