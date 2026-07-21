# Docker Cheatsheet

## Containers
```bash
docker run -d --name web -p 8080:80 nginx                  # detached, named, mapped port
docker run --rm -it alpine sh                              # interactive, auto-remove
docker run --user 1000 --read-only --cap-drop=ALL nginx    # hardened
docker ps                                                  # running
docker ps -a                                               # incl stopped
docker logs -f --tail 100 web                              # tail logs
docker exec -it web sh                                     # shell in
docker stop web && docker rm web                           # stop + remove
docker inspect web | jq '.[0].State'
docker stats                                               # live cpu/mem
docker top web                                             # processes
docker cp file.txt web:/tmp/                               # copy file in
docker cp web:/etc/nginx/nginx.conf .                      # copy file out
```

## Images
```bash
docker images
docker pull alpine:3.20
docker rmi alpine:3.20
docker tag myapp:1.0 ghcr.io/me/myapp:1.0
docker push ghcr.io/me/myapp:1.0
docker history nginx:alpine
docker save -o image.tar myapp:1.0                         # export
docker load -i image.tar                                   # import
docker image prune -a                                      # remove all unused
```

## Build
```bash
docker build -t myapp:1.0 .
docker build --no-cache -t myapp:1.0 .
docker build --build-arg VERSION=1.0 -t myapp:1.0 .
docker build --target build -t myapp:dev .                 # stop at named stage

DOCKER_BUILDKIT=1 docker build -t myapp:1.0 .
docker buildx build --platform linux/amd64,linux/arm64 -t me/app --push .
docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myapp .
```

## Volumes
```bash
docker volume create mydata
docker volume ls
docker volume inspect mydata
docker volume rm mydata
docker volume prune
docker run -v mydata:/data alpine                          # named
docker run -v $PWD:/app alpine                             # bind
docker run -v $PWD:/app:ro alpine                          # bind read-only
docker run --tmpfs /scratch:size=64m alpine                # tmpfs
```

## Networks
```bash
docker network ls
docker network create app-net
docker network inspect app-net
docker network connect app-net web
docker network disconnect app-net web
docker run --network app-net --name web nginx
docker run --network host nginx                            # share host net (Linux)
docker run --network none alpine                           # no networking
```

## Compose
```bash
docker compose up -d
docker compose ps
docker compose logs -f web
docker compose exec web sh
docker compose restart web
docker compose pull
docker compose build
docker compose down               # keep volumes
docker compose down -v            # also remove volumes
docker compose config             # render final yaml
docker compose --profile debug up
docker compose -f a.yml -f b.yml up
```

## Registry
```bash
echo $TOKEN | docker login ghcr.io -u me --password-stdin
docker logout ghcr.io
docker manifest inspect ghcr.io/me/app:1.0
docker buildx imagetools inspect ghcr.io/me/app:1.0
```

## System
```bash
docker version
docker info
docker system df                  # disk usage
docker system prune -a --volumes  # nuke unused
docker events                     # daemon event stream
```

## Security
```bash
trivy image --severity HIGH,CRITICAL myapp:1.0
grype myapp:1.0
cosign sign --key cosign.key ghcr.io/me/app:1.0
cosign verify --key cosign.pub ghcr.io/me/app:1.0
syft myapp:1.0 -o spdx-json > sbom.json
```

## Hardened `docker run`
```bash
docker run -d \
  --name app \
  --user 10001:10001 \
  --read-only \
  --tmpfs /tmp:size=64m \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  --memory 256m --cpus 0.5 \
  --pids-limit 100 \
  --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  ghcr.io/me/app:1.0
```

## Common Dockerfile snippets
```dockerfile
# Cache-friendly
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# Non-root
RUN groupadd --system app && useradd --system --gid app app
USER app

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

# BuildKit cache
# syntax=docker/dockerfile:1.7
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

# BuildKit secret
RUN --mount=type=secret,id=token cat /run/secrets/token
```

## Killers
```bash
docker stop $(docker ps -q)              # stop all running
docker rm $(docker ps -aq)               # remove all containers
docker rmi $(docker images -q)           # remove all images
docker system prune -a --volumes -f      # nuke everything
```
