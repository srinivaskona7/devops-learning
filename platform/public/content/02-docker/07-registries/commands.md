# Registries — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm docker has registry credentials configured
cat ~/.docker/config.json
```

## Core commands

```bash
# Build a local image
docker build -t myapp:1.0 .
```

```bash
# Tag for a destination registry (GHCR example)
docker tag myapp:1.0 ghcr.io/myuser/myapp:1.0
```

```bash
# Tag the same SHA as :latest too
docker tag myapp:1.0 ghcr.io/myuser/myapp:latest
```

```bash
# Login to GHCR using a PAT from stdin (safer than -p on cmdline)
echo $GITHUB_PAT | docker login ghcr.io -u myuser --password-stdin
```

```bash
# Push a single tag
docker push ghcr.io/myuser/myapp:1.0
```

```bash
# Push every tag for a repo at once
docker push --all-tags ghcr.io/myuser/myapp
```

```bash
# Pull from any reachable registry
docker pull ghcr.io/myuser/myapp:1.0
```

```bash
# Pull a public image from GCR (no auth needed)
docker pull gcr.io/google-samples/hello-app:1.0
```

## Build / run examples

```bash
# Spin up a private registry on localhost:5000 with a persistent volume
docker run -d -p 5000:5000 --name registry \
  -v regdata:/var/lib/registry \
  registry:2
```

```bash
# Push something into it
docker tag alpine:3.20 localhost:5000/alpine:3.20
docker push localhost:5000/alpine:3.20
```

```bash
# Re-pull from the local registry (after deleting the local copy)
docker rmi localhost:5000/alpine:3.20
docker pull localhost:5000/alpine:3.20
```

## Inspection / verification

```bash
# List repos in the local registry via its v2 API
curl http://localhost:5000/v2/_catalog
```

```bash
# List tags for a repo
curl http://localhost:5000/v2/alpine/tags/list
```

```bash
# Look at a remote image's manifest WITHOUT pulling it
docker manifest inspect ghcr.io/myuser/myapp:1.0
```

```bash
# crane: inspect manifest of a remote image
crane manifest gcr.io/google-samples/hello-app:1.0 | jq .
```

```bash
# crane: inspect the image config (cmd, env, layers)
crane config gcr.io/google-samples/hello-app:1.0 | jq .
```

## Cleanup

```bash
# Logout of a registry (clears creds)
docker logout ghcr.io
```

```bash
# Remove the local registry container
docker rm -f registry
```

## One-liners worth memorising

```bash
# CI tagging pattern: SHA + version + latest, then push all
SHA=$(git rev-parse --short HEAD)
VERSION=$(git describe --tags --always)
docker build -t myapp:$SHA -t myapp:$VERSION -t myapp:latest .
```

```bash
# Pin to an immutable digest (for K8s manifests / Dockerfile FROM)
docker buildx imagetools inspect ghcr.io/myuser/myapp:1.0 | grep Digest
```
