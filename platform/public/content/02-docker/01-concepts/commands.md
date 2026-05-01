# Concepts — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Verify docker daemon is responsive (concepts only — no install here)
docker version
```

```bash
# Show daemon-side info: storage driver, cgroup driver, runtime, kernel
docker info
```

## Core commands

```bash
# Pull a base image so we have layers to inspect
docker pull nginx:1.27-alpine
```

```bash
# Run a throwaway container in the background to peek inside
docker run --rm -d --name demo nginx:1.27-alpine
```

## Build / run examples

```bash
# Start a demo container we can exec into for namespace exploration
docker run --rm -d --name demo nginx:1.27-alpine
```

## Inspection / verification

```bash
# Show ordered layer history (instructions + sizes) for an image
docker history nginx:1.27-alpine
```

```bash
# Dump the layer digests that compose the image rootfs
docker inspect nginx:1.27-alpine | jq '.[0].RootFS'
```

```bash
# List the namespace handles the container's PID 1 lives in
docker exec demo ls -la /proc/1/ns
```

```bash
# Compare to host namespaces — different inode numbers prove isolation (Linux)
ls -la /proc/1/ns
```

```bash
# Inspect cgroup driver / runtime in use on the daemon
docker info | grep -E 'Cgroup|Runtime|Storage'
```

```bash
# (Linux) list namespaces visible to your shell — confirms host vs container view
lsns
```

```bash
# (Linux) enter a fresh namespace set the way a runtime would
unshare --user --pid --mount --net --uts --ipc --fork bash
```

## Cleanup

```bash
# Stop + remove the demo container
docker rm -f demo
```

```bash
# Drop the pulled base image if you're done exploring
docker rmi nginx:1.27-alpine
```

## One-liners worth memorising

```bash
# What kernel features back this container? — namespaces under PID 1
docker exec demo readlink /proc/1/ns/pid /proc/1/ns/mnt /proc/1/ns/net
```

```bash
# Confirm OCI runtime + storage driver in one shot
docker info --format 'runtime={{.DefaultRuntime}} storage={{.Driver}} cgroup={{.CgroupDriver}}'
```

```bash
# How many layers does this image actually have?
docker inspect nginx:1.27-alpine | jq '.[0].RootFS.Layers | length'
```
