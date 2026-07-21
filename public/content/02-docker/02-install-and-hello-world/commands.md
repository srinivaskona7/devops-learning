# Install + Hello World — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# macOS: install Docker Desktop via Homebrew cask
brew install --cask docker
```

```bash
# macOS: launch the Docker Desktop app (starts the daemon VM)
open -a Docker
```

```bash
# Linux (dev only): convenience script — read it before piping to sh
curl -fsSL https://get.docker.com | sh
```

```bash
# Linux: add yourself to the docker group so sudo isn't required
sudo usermod -aG docker $USER
```

```bash
# Confirm client + server versions
docker version
```

```bash
# Show daemon summary (containers, images, storage driver)
docker info | head -20
```

## Core commands

```bash
# Download an image from a registry into the local cache
docker pull <image>
```

```bash
# List locally cached images
docker images
```

```bash
# Delete a local image
docker rmi <image>
```

```bash
# Create + start a container in one shot
docker run [opts] <image> [cmd]
```

```bash
# List running containers
docker ps
```

```bash
# List all containers including stopped ones
docker ps -a
```

```bash
# Stream stdout/stderr from a container
docker logs <id>
```

```bash
# Open an interactive shell in a running container
docker exec -it <id> sh
```

```bash
# Send SIGTERM (then SIGKILL after grace) to a running container
docker stop <id>
```

```bash
# Delete a stopped container
docker rm <id>
```

## Build / run examples

```bash
# First container — proves the install works end-to-end
docker run hello-world
```

```bash
# Pull the GCR sample app
docker pull gcr.io/google-samples/hello-app:1.0
```

```bash
# Run detached, name it "hello", publish 8080
docker run -d --name hello -p 8080:8080 gcr.io/google-samples/hello-app:1.0
```

```bash
# Hit it from the host
curl localhost:8080
```

```bash
# Tail logs by name
docker logs hello
```

```bash
# Shell into the running container
docker exec -it hello sh
```

## Inspection / verification

```bash
# Confirm container is up and which port is published
docker ps
```

```bash
# Resolve the host port mapping for an exposed container port
docker port hello
```

## Cleanup

```bash
# Stop then delete the named container
docker stop hello && docker rm hello
```

```bash
# Remove all stopped containers
docker container prune
```

```bash
# Remove dangling (untagged) images
docker image prune
```

```bash
# Remove ALL unused images, not just dangling ones
docker image prune -a
```

```bash
# Remove unused volumes
docker volume prune
```

```bash
# Remove unused networks
docker network prune
```

```bash
# Nuke every unused container, image, network, and volume
docker system prune -a --volumes
```

## One-liners worth memorising

```bash
# Run + auto-remove a throwaway shell in alpine
docker run --rm -it alpine sh
```

```bash
# Restart a previously stopped container by name (NOT docker run again)
docker start <name>
```
