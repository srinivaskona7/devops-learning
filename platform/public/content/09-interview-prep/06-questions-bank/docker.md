# Docker Q&A Bank

These questions are the ones I've actually been asked / would ask. Container basics get probed in every DevOps screen — interviewers want to know you understand layers, namespaces, and image security, not just `docker run`.

## How to use

Say each answer out loud, 60-second ceiling. Sketch the layer/network model on a whiteboard. Be ready for "what if" follow-ups: "what if the container needs to write to a layer below?", "what if two containers share a volume?".

---

## Images & Layers

**Q1. What is a container image?**
A read-only filesystem bundle plus metadata (entrypoint, env, exposed ports). Stored as a stack of layers, each a tarball of filesystem changes. Identified by content-addressable SHA256 digest. Pulled from a registry, instantiated as a container.

**Q2. Explain Docker layers.**
Each Dockerfile instruction (RUN, COPY, ADD) creates a new layer — a diff over the previous. Layers are cached and shared between images. A container adds a thin writable layer on top via copy-on-write (overlay2).

**Q3. Difference between an image and a container?**
Image is the static template (read-only layers). Container is a running (or stopped) instance with its own writable layer, namespaces, and process. Many containers can share one image.

**Q4. What's the difference between CMD and ENTRYPOINT?**
ENTRYPOINT is the executable; CMD is its default args (overridable at `docker run`). Best practice: ENTRYPOINT in exec form `["app"]`, CMD as default flags `["--port", "8080"]`. Using only CMD lets users replace the whole command.

**Q5. Why does `RUN apt-get update && apt-get install -y x` go on one line?**
To stay in a single layer and ensure update is fresh when install runs. If split, the cached `apt-get update` layer can serve stale package indexes for weeks. Always combine and end with `&& rm -rf /var/lib/apt/lists/*` to slim the layer.

**Q6. What is a multi-stage build?**
A Dockerfile with multiple `FROM` statements. Build artifacts in a fat builder stage, then `COPY --from=builder` into a minimal runtime stage. Final image excludes compilers, source, and build deps. Standard pattern for Go, Java, Node.

**Q7. How do you reduce image size?**
Multi-stage builds, alpine/distroless base, combine RUN commands, `.dockerignore` to exclude junk, remove package manager caches, avoid ADD with URLs (use COPY + curl in same RUN), prune unused locales/docs.

**Q8. What is a distroless image?**
Google-maintained images with only the app and its runtime deps — no shell, no package manager, no busybox. Tiny attack surface. Debug via `:debug` variant or sidecar with shell.

**Q9. What's the difference between COPY and ADD?**
COPY copies local files into the image. ADD additionally supports remote URLs and auto-extracts tar archives. Best practice: prefer COPY; explicit `RUN curl + tar` is clearer than ADD's magic.

**Q10. Explain the Docker build cache.**
Each instruction is hashed (instruction text + input files for COPY/ADD). If hash matches a previous build, the cached layer is reused. Order matters — put rarely-changing layers (deps install) before frequently-changing ones (source code).

**Q11. What is a layer's "context" in `docker build`?**
The directory you pass to `docker build .` — the build daemon receives the entire tree (minus .dockerignore). Large contexts slow builds and bloat builders. COPY/ADD can only reference files inside the context.

---

## Containers & Runtime

**Q12. What does `docker run` actually do?**
Pulls image if missing, creates a container (writable layer + config), creates network/volumes, starts the container's process in new namespaces with cgroup limits, attaches stdin/stdout per flags. Container exits when PID 1 exits.

**Q13. How do containers achieve isolation?**
Linux namespaces (PID, NET, MNT, IPC, UTS, USER, CGROUP) for visibility isolation, cgroups for resource limits, capabilities to drop root powers, seccomp filters to restrict syscalls, AppArmor/SELinux for MAC. Not a security boundary like a VM — kernel is shared.

**Q14. Container vs VM?**
Container shares the host kernel, isolated by namespaces — fast startup (ms), low overhead, dense packing. VM has its own kernel via hypervisor — stronger isolation, slower boot, higher memory cost. Use containers for app packaging; VMs when you need different kernels or hard isolation.

**Q15. Why must PID 1 in a container handle signals?**
Linux ignores SIGTERM for PID 1 unless a handler is registered. Apps not designed for PID 1 won't shut down gracefully on `docker stop`. Use `tini` or `dumb-init` as init, or write apps that handle SIGTERM.

**Q16. What happens on `docker stop` vs `docker kill`?**
`docker stop` sends SIGTERM, waits 10s (configurable), then SIGKILL. `docker kill` sends SIGKILL immediately (or whatever signal you specify). Always use stop; kill leaves apps no chance to flush state.

**Q17. How do you debug a crashed container?**
`docker logs <id>` for stdout/stderr. `docker inspect <id>` for state, exit code, OOM flag. `docker run --rm -it --entrypoint sh <image>` to poke around the image. For a still-running container: `docker exec -it <id> sh`. If image lacks shell, use `nsenter` from host.

**Q18. Why is `latest` tag dangerous?**
It's mutable — what `latest` points to can change between builds. Causes irreproducible deployments and silent upgrades. Pin to immutable digests (`@sha256:...`) or semantic versions in production.

**Q19. What does `--restart unless-stopped` do?**
Restart the container on exit unless it was explicitly stopped. Survives daemon restart. Use for long-running services. Alternatives: `no` (default), `on-failure[:N]`, `always`.

---

## Networking

**Q20. Explain Docker's default bridge network.**
A virtual L2 bridge `docker0` on the host. Each container gets a veth pair — one end in the container's net namespace (eth0), other attached to the bridge. Containers get IPs from a private subnet (172.17.0.0/16). NAT via iptables for outbound.

**Q21. Difference between bridge, host, and none network modes?**
bridge: default, isolated network with NAT. host: container shares host's network namespace (no isolation, no port mapping needed). none: no networking at all (loopback only). overlay: multi-host (Swarm/Kubernetes).

**Q22. How do containers on the same user-defined network find each other?**
Docker's embedded DNS resolves container names to IPs within a user-defined network. The default bridge does NOT have DNS — always create networks: `docker network create mynet`.

**Q23. What does `-p 8080:80` mean and how does it work?**
Maps host port 8080 to container port 80. Implemented via iptables DNAT rule in the nat table. Traffic to host:8080 is rewritten to container_ip:80. `-p 127.0.0.1:8080:80` binds only to loopback.

**Q24. EXPOSE vs -p?**
EXPOSE in Dockerfile is documentation/metadata only — doesn't publish the port. `-p` (or `-P` for all EXPOSEd) actually creates the port mapping. EXPOSE matters for Compose's auto-linking and `-P`.

**Q25. How would a container reach a service on the host?**
Linux: use `host.docker.internal` (Docker Desktop) or the host's docker0 IP (typically 172.17.0.1). Or run container with `--network host`. In production K8s, use a Service/headless endpoint instead.

---

## Volumes & Storage

**Q26. Difference between volume, bind mount, tmpfs?**
Volume: managed by Docker in `/var/lib/docker/volumes`, portable, survives container removal. Bind mount: arbitrary host path mounted in — host-coupled, useful for dev. tmpfs: RAM-backed, ephemeral, for secrets/scratch.

**Q27. Why prefer named volumes over bind mounts in production?**
Volumes are managed (backup, migrate, drivers for cloud storage). Bind mounts depend on host paths existing with right perms — fragile across hosts. Volumes also support drivers (NFS, EBS, etc.).

**Q28. What happens to data when a container is removed?**
The writable layer is deleted. Anything on a mounted volume persists. Anything written to the container FS but not to a volume is lost.

**Q29. How do you back up a Docker volume?**
Run a temporary container with the volume mounted and tar it: `docker run --rm -v myvol:/data -v $(pwd):/backup alpine tar czf /backup/vol.tar.gz -C /data .`. Restore by extracting into a fresh volume.

---

## Registries & Distribution

**Q30. What's in an image manifest?**
JSON describing the image: layer digests, config digest, platform (os/arch), media types. With manifest lists (OCI index), one tag can point to multiple platform-specific manifests for multi-arch images.

**Q31. How do you push to a private registry?**
`docker login registry.example.com`, tag image as `registry.example.com/team/app:v1`, `docker push`. Auth stored in `~/.docker/config.json` (consider credential helpers for prod).

**Q32. Explain image digests vs tags.**
Tag is a mutable human-readable name (`nginx:1.25`). Digest is the immutable SHA256 of the manifest (`nginx@sha256:abc...`). Production deployments should pin digests for reproducibility; tags can be re-pushed.

**Q33. What is OCI?**
Open Container Initiative — vendor-neutral specs for image format and runtime. Docker images are OCI-compatible. Other runtimes (containerd, CRI-O, podman) consume OCI images. Decouples image format from Docker the company.

---

## Security

**Q34. Why shouldn't containers run as root?**
If a container escapes (kernel exploit, misconfigured mount), root in container is root on host. Always `USER nonroot` in Dockerfile. Combine with `--read-only`, dropped capabilities, seccomp profile.

**Q35. What capabilities should you drop?**
Drop ALL, add back only what's needed: `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`. Default Docker keeps ~14 caps including potentially dangerous ones (CAP_NET_RAW for ARP spoofing).

**Q36. How do you scan an image for vulnerabilities?**
Trivy, Grype, Snyk, Docker Scout. CI pattern: scan every PR, fail on HIGH/CRITICAL. Also scan base images regularly — yesterday's clean image is today's CVE-laden one.

**Q37. What is `--read-only` and when do you use it?**
Mounts the container's root FS as read-only. Forces app to write only to explicit volumes/tmpfs. Best practice for stateless services — eliminates many persistence-based exploits.

**Q38. How do you handle secrets in Docker?**
Don't bake into images, don't pass via env vars (visible in `docker inspect`, leaked to logs). Use Docker secrets (Swarm), bind-mounted files from a secrets manager, or external systems (Vault, AWS Secrets Manager) fetched at startup.

**Q39. What is a SBOM and why does it matter?**
Software Bill of Materials — list of all components (libraries, OS packages) in an image. Required for supply-chain security (SLSA, executive orders). Generated by syft, docker buildx, dive.

**Q40. Explain rootless Docker.**
Run dockerd as a non-root user via user namespaces. Containers inside still see "root" but it maps to a normal UID on host. Reduces blast radius of daemon compromise. Trade-off: some features (host networking, low ports) need extra setup.

**Q41. What is a base image you'd recommend for production Go apps?**
Distroless (`gcr.io/distroless/static:nonroot`) for static binaries, or `scratch` if no certs/timezone needed. Both eliminate shell + package manager attack surface.

---

## Compose & Orchestration

**Q42. What is docker-compose used for?**
Declarative multi-container apps for dev/test. One YAML defines services, networks, volumes. `docker compose up` brings the stack up. Not for production orchestration — use Kubernetes for that.

**Q43. depends_on doesn't wait for service health — what do you do?**
Use `depends_on` with `condition: service_healthy` (Compose v2.1+) and define a `healthcheck` on the dependency. Or implement retry/backoff in the app's startup. Don't rely on bare `depends_on` for boot order with stateful deps.

**Q44. Why would you avoid `:latest` in compose files?**
Same reason as anywhere — non-reproducible deployments. Pin tags, ideally with digests in production.
