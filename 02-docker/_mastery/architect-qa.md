# Architect-Level Docker Q&A

Audience: 15-year platform/infra architects designing for thousands of nodes, regulated supply chains, and mixed-tenancy runtimes. Answers favor tradeoffs over recipes.

> 20-year tip: most "Docker problems" at scale are actually registry, kernel, or filesystem problems. Always classify before acting.

---

## Section 1: Image Distribution at 10k-Node Fleet Scale

### Q1. A 10k-node fleet rolls a new image at deploy time. What goes wrong first?
Registry bandwidth and connection saturation. A single 500 MB image pulled by 10k nodes simultaneously is 5 TB egress in minutes. The registry's TCP accept queue, TLS handshake CPU, and upstream blob store throughput collapse before the network does.

### Q2. Mitigation hierarchy?
1. Pull-through caches per AZ (Harbor, Artifactory, registry:2 with proxy mode)
2. Per-rack mirror or P2P (Dragonfly, Kraken, Spegel)
3. Lazy-pulling snapshotters (stargz, eStargz, Nydus) so containers start before full pull
4. Slot deploys (canary, ring, % staggered)
5. Pre-pull via DaemonSet/Ansible at low-watermark hours

### Q3. When is P2P (Dragonfly/Kraken/Spegel) worth the operational cost?
When you have >500 nodes per cluster and image pulls dominate deploy latency. Below that, a tiered pull-through cache is simpler and 90% as good. P2P shines when nodes already have most layers and only need deltas — i.e., long-lived clusters with frequent small rebuilds.

### Q4. Spegel vs Dragonfly tradeoffs?
- Spegel: Kubernetes-native, uses containerd's existing layer store, no extra daemon. Limited to in-cluster peers.
- Dragonfly: standalone, supports cross-cluster, more features (preheat, scheduling), heavier operational footprint.

### Q5. Why are blob digests load-bearing for distribution?
Content-addressable storage means every cache layer can verify integrity without trusting the source. A blob is `sha256:<hash>`; any cache that returns wrong bytes is detected immediately. This is what makes pull-through caches safe.

### Q6. What's the failure mode when a registry returns 429 mid-pull?
containerd retries with backoff but holds the in-progress layer. If 10k nodes all back off in sync, you get a thundering herd on retry. Fix: jittered backoff in containerd config, or a queue-based puller (kube-image-prefetch).

### Q7. ECR/GCR/ACR rate limits — what's the real limit?
ECR: 10 TPS per account per region for `BatchGetImage`, but blob downloads via S3-backed CDN are effectively unlimited. The bottleneck is the manifest API, not the data path. Pre-resolving manifests once per AZ solves it.

### Q8. When is image streaming (stargz/Nydus) worth adopting?
When p99 cold start matters and images are >200 MB with sparse access patterns (most files in the image are never read). ML containers and JVM apps benefit dramatically. Tight, scratch-based Go binaries don't.

> 20-year tip: measure layer access patterns with `nydus-image inspect` before adopting streaming. If 90% of bytes are read in the first 10 seconds, streaming gives you nothing.

---

## Section 2: Multi-Arch Supply Chain

### Q9. When does QEMU emulation in `buildx` become unacceptable?
When build time exceeds 10 minutes or when native libraries (glibc, OpenSSL) behave differently under emulation. Use native arm64 runners for arm64 builds. The 5-10x speedup pays for the runner cost.

### Q10. Manifest list vs OCI image index?
Functionally equivalent for multi-arch. OCI index is the spec-compliant version; Docker manifest list (v2) is the legacy. Modern registries accept both. Use `--provenance=true --sbom=true` with buildx to get attestation manifests attached.

### Q11. How do you sign multi-arch images?
Sign the index, not each platform manifest. cosign signs the digest of the index; verifiers resolve platform at pull time and trust the index signature transitively. Signing per-platform is wasteful and creates verification ambiguity.

### Q12. SLSA provenance for container images — what level is realistic?
SLSA Level 3 with GitHub Actions + cosign + Sigstore Rekor is achievable today. Level 4 requires hermetic builds (no network during build, pinned toolchains), which means BuildKit with `--network=none` and vendored dependencies.

### Q13. Where does the SBOM live?
Attached as an OCI artifact referencing the image digest, via the OCI 1.1 referrers API. Older registries embed SBOM as a separate tag (`<image>-sbom`). Use `cosign attach sbom` or `syft attest`.

### Q14. Reproducible builds — what breaks them?
- Timestamps (set `SOURCE_DATE_EPOCH`)
- Package manager metadata (apt cache, pip wheel build hashes)
- File ordering in tar layers
- Random UIDs in `useradd`
BuildKit's `--output type=docker,rewrite-timestamp=true` handles most of it.

### Q15. Why do `linux/amd64` images sometimes pull on M-series Macs without `--platform`?
Docker Desktop installs binfmt_misc + qemu and silently runs amd64 images. This works but is 5-10x slower and breaks on syscalls QEMU doesn't emulate (e.g., `io_uring`). Always explicitly set `--platform=linux/arm64` in dev.

---

## Section 3: Registry Tiering

### Q16. Recommended tier topology for a global SaaS?
- Tier 0: source-of-truth registry (ECR/Harbor in primary region)
- Tier 1: regional pull-through caches (one per region, replicated)
- Tier 2: per-cluster mirror or in-cluster Spegel
- Tier 3: node-local containerd image store
Pulls walk down; pushes only hit Tier 0.

### Q17. Harbor vs Artifactory vs Quay vs cloud-native?
- Harbor: open-source, best for K8s-native (replication, signing, RBAC). Operational burden non-trivial.
- Artifactory: best when you also store maven/npm/pypi; expensive.
- Quay: best for OpenShift shops; security scanning included.
- ECR/GCR/ACR: cheapest if you're all-in on one cloud; cross-cloud replication is painful.

### Q18. How do you handle a registry outage?
Registry mirrors in containerd config (`mirrors` block) with multiple endpoints. containerd tries them in order. Combined with tier-1 caches, a primary registry outage is invisible for cached images; new images simply don't deploy. This is acceptable.

### Q19. Garbage collection at scale — what bites?
Mark-and-sweep GC on a 10 TB registry takes hours and locks writes (older registries) or slows them (newer). Run during low-traffic windows. Use Harbor's tag retention policies to keep image count manageable. Untagged manifests are the silent disk-eater.

### Q20. Pull-through cache sizing?
Working set = unique images × avg size × 2 (for upgrades in flight). A 1k-image fleet averaging 300 MB needs ~600 GB. Use SSD; HDD will bottleneck on metadata ops.

> 20-year tip: registry storage is cheap; registry CPU is not. Sign and scan asynchronously, not in the push path.

---

## Section 4: BuildKit Cache Topology

### Q21. Cache backends, ranked by ops cost vs hit rate?
1. `--cache-to type=inline` — free, low hit rate, only single-stage
2. `--cache-to type=registry` — needs registry, good hit rate, multi-stage
3. `--cache-to type=gha` — GitHub Actions only, capped at 10 GB per repo
4. `--cache-to type=s3` — best for self-hosted CI, unlimited size, requires bucket lifecycle
5. `--cache-to type=local` — only useful for single-machine builds

### Q22. Cache key composition — what changes invalidate?
The build graph hash includes: instruction text, source file digests, mount contents, secret IDs (not values), platform. ARG values invalidate downstream layers. `RUN` commands invalidate on text change, not output.

### Q23. Cache mount (`--mount=type=cache`) lifecycle?
Persists across builds within the same builder. Sharing modes: `shared` (concurrent reads/writes, racy), `private` (per-build copy), `locked` (mutex). Use `locked` for package managers (apt, npm) to avoid corruption.

### Q24. Why do cache hits regress on a Friday afternoon?
Likely a base image float (`FROM node:20` resolved to a new digest). Pin to digests in CI. Other causes: BuildKit GC ran, secret ID changed, builder restarted (for non-persistent backends).

### Q25. Multi-stage cache export — what's the gotcha?
`--cache-to type=registry,mode=max` exports all stages including intermediates. `mode=min` exports only the final stage's layers. `max` gives better hit rates but uses 5-10x more registry space. Default is `min`.

### Q26. Distributed BuildKit — when?
When you have >50 builds/hour and CI runners can't handle the load. Run `buildkitd` as a deployment in K8s, point CI at it via `buildx create --driver=remote`. Cache is shared automatically. Networking and TLS are non-trivial; budget a sprint.

---

## Section 5: Security Hardening Tradeoffs

### Q27. Rootless Docker — when does it actually help?
Defense in depth on shared CI runners and dev workstations. In production, you should be on K8s with a hardened runtime; rootless Docker is irrelevant there. The cost is performance (fuse-overlayfs is slower than overlay2) and feature loss (no host networking, port <1024 needs setcap).

### Q28. User namespaces (`userns-remap`) vs rootless?
Userns-remap: dockerd runs as root, container UIDs map to subordinate UIDs on host. Rootless: dockerd itself runs as user. Userns-remap is easier to adopt (no daemon change) and gives 80% of the benefit. Both break shared-volume UID assumptions.

### Q29. Seccomp default profile — what does it block?
~44 syscalls including `keyctl`, `add_key`, `kexec_load`, most of the mount family. Catches privilege-escalation primitives. Custom profiles are needed for things like Chrome (needs `clone3`), but rarely.

### Q30. AppArmor vs SELinux for containers?
AppArmor: path-based, easier to write, default on Ubuntu/Debian. SELinux: label-based, stronger isolation, default on RHEL/Fedora. Both work; pick whichever your distro defaults to. Don't disable.

### Q31. Capabilities — what's safe to drop?
Drop ALL, add back only what you need. 90% of containers need none. The 10% need `NET_BIND_SERVICE` (port <1024), `SYS_PTRACE` (debuggers), `NET_ADMIN` (network tools). Never grant `SYS_ADMIN`; it's near-equivalent to root.

### Q32. Read-only root filesystem — what breaks?
Apps that write to `/tmp`, `/var/log`, or app-relative paths. Solution: mount `tmpfs` at writable locations (`--tmpfs /tmp`). Forces you to find hidden writes; this is usually a good thing.

### Q33. Image vulnerability scanning — SCA vs runtime?
SCA (Trivy, Grype, Snyk): scans image layers at build time, finds CVEs in installed packages. Cheap, catches 80% of known issues. Runtime (Falco, Tetragon): detects exploitation in production, catches the other 20% plus zero-days. Both, not either.

### Q34. Distroless vs Alpine vs scratch?
- scratch: smallest, hardest to debug (no shell)
- distroless: small, no package manager, has tzdata/ssl, debug variant exists
- Alpine: small, has busybox shell, musl libc (DNS quirks, glibc-built binaries fail)
For Go: scratch or distroless. For Java/Python: distroless. Avoid Alpine for anything with CGO unless you've tested DNS heavily.

> 20-year tip: musl vs glibc DNS bugs cost you a weekend at least once per career. Use distroless for the language runtime; you'll thank yourself.

---

## Section 6: Runtime Selection

### Q35. runc vs crun?
crun is C, runc is Go. crun is 2-3x faster at container start, ~50% less memory. Functionally equivalent (both OCI runtime spec). RHEL 9 defaults to crun. Switch if container start latency matters.

### Q36. When does gVisor make sense?
Multi-tenant workloads where you don't trust the container (CI runners executing PR code, FaaS, hosted notebooks). gVisor implements syscalls in userspace; reduces kernel attack surface dramatically. Cost: 10-30% performance overhead, some syscalls unsupported (no `io_uring`, limited `eBPF`).

### Q37. Kata Containers — when?
When you need VM-level isolation but container UX. Each container runs in a microVM (firecracker or QEMU). Used by hyperscalers for hostile multi-tenancy. Overhead: 50-200ms cold start, 50-100 MB memory per container. Worth it for untrusted workloads in regulated environments.

### Q38. Firecracker vs Kata?
Firecracker is a VMM, Kata is the container runtime that can use Firecracker (or QEMU). AWS Lambda and Fargate use Firecracker directly. Kata adds the OCI compatibility layer.

### Q39. Runtime selection matrix?
| Workload | Runtime |
|----------|---------|
| Trusted internal service | runc/crun |
| Multi-tenant SaaS, tenants can't see each other | gVisor or Kata |
| Untrusted code execution (CI, FaaS) | gVisor or Firecracker |
| GPU workloads | runc + nvidia-container-toolkit (gVisor doesn't support GPUs) |
| Windows containers | hcsshim (no choice) |

### Q40. Why does gVisor break some apps silently?
Sentry (gVisor's userspace kernel) doesn't implement every syscall. Apps using `io_uring`, `userfaultfd`, or exotic `ptrace` features fail with `ENOSYS`. Test thoroughly; fall back to runc for those workloads.

---

## Section 7: Storage and Filesystems

### Q41. overlay2 vs fuse-overlayfs vs btrfs?
- overlay2: kernel, fast, default. Requires root or userns-remap.
- fuse-overlayfs: userspace, slower (~30%), works rootless.
- btrfs: COW snapshots, used by some CI systems for speed. Operational complexity.
Default is overlay2 unless you have a reason.

### Q42. Layer count limit?
Hard limit: 127 layers (overlay2 mount limit). Practical limit: ~40 before performance degrades on metadata ops. Keep Dockerfiles tight; combine `RUN` commands when logical.

### Q43. Why do `COPY` operations on large dirs slow down builds?
Each `COPY` creates a layer; large layers slow extraction and registry ops. For node_modules-style trees, use `--mount=type=bind` in BuildKit instead of `COPY` when the data is build-only.

### Q44. inode exhaustion — when does it bite?
Images with millions of small files (node_modules, Python site-packages). Each file is an inode in overlay2. Default ext4 inode count may be exceeded on small disks. Monitor `df -i`, not just `df`.

---

## Section 8: Networking Deep Dive

### Q45. bridge vs host vs macvlan vs ipvlan?
- bridge: default, NAT'd, slowest, most compatible
- host: no isolation, fastest, port conflicts
- macvlan: container gets its own MAC on host network, near-bare-metal speed
- ipvlan L3: shares MAC, separate IPs, easier on switches
Use bridge for dev, macvlan/ipvlan for high-throughput production.

### Q46. iptables vs nftables vs eBPF for container networking?
Docker uses iptables by default. Modern K8s (Cilium) uses eBPF, bypassing iptables entirely. For 10k-rule scale, iptables becomes a bottleneck (linear lookup). nftables is the in-between option (set-based lookup). For Docker standalone, iptables is fine until you have 1000+ containers per host.

### Q47. DNS inside containers — what's the resolver path?
Container's `/etc/resolv.conf` points to embedded DNS at `127.0.0.11:53`. Docker's resolver handles container name lookups, forwards external queries to host's resolver. Misconfigured `--dns` flags cause the famous "intermittent DNS failure" in Alpine images (musl's parallel A+AAAA query bug).

### Q48. Why does `localhost` inside a container not reach the host?
Container has its own network namespace; `localhost` is the container's loopback. Use `host.docker.internal` (Docker Desktop) or `--add-host=host.docker.internal:host-gateway` (Linux 20.10+).

---

## Section 9: OCI Spec and Distribution

### Q49. Image manifest v2 schema 2 vs OCI manifest?
Nearly identical; OCI is the standardized fork. mediaTypes differ (`application/vnd.docker.*` vs `application/vnd.oci.*`). Modern registries accept both. New work should use OCI.

### Q50. OCI artifact spec — what changes?
OCI 1.1 lets you store any artifact (Helm charts, SBOMs, signatures, WASM modules) in a registry, with a referrers API to link them to images. This is the foundation of modern supply chain (cosign signatures, Syft SBOMs all use it).

### Q51. Distribution spec — the contract registries must implement?
Defines `/v2/` HTTP API: blob upload (chunked, monolithic), manifest push/pull, tag listing, referrers. Any compliant registry works with any compliant client. This is why Harbor, ECR, and Docker Hub are interchangeable at the protocol level.

---

## Section 10: Production Incidents

### Q52. "Container OOMKilled with no app logs" — diagnosis?
Kernel OOM killer terminated PID 1 before app could log. Check `dmesg` on host for the OOM message; it tells you the actual RSS at kill time. Common cause: cgroup memory limit < JVM heap + non-heap + native (Netty, JNI).

### Q53. "Pull works on my laptop, fails in production" — usual suspect?
Auth. Laptop has cached creds in `~/.docker/config.json`; prod node uses an outdated credential helper or expired ECR token. Second suspect: platform mismatch (laptop is arm64, prod is amd64).

### Q54. "Container runs fine for hours then dies" — patterns?
1. Memory leak hits cgroup limit → OOMKilled
2. File descriptor leak hits ulimit → app crashes with EMFILE
3. Log volume fills disk → app can't write → crashes
4. Expired credentials (IAM, vault token) → app can't refresh → exits

### Q55. "Image vulnerability appeared overnight" — what happened?
A new CVE was published; your scanner's DB updated. The image didn't change; the world's understanding of it did. This is normal. Process: triage by exploitability and reachability, patch base image, rebuild.

> 20-year tip: vuln noise is the #1 reason teams stop scanning. Tune by reachability (does your code call the vulnerable function?) not just severity.

### Q56. Build cache poisoned across PR branches — how?
Shared registry cache + identical cache key + different base image → wrong layers reused. Fix: include base image digest in cache key, use per-branch cache scopes (BuildKit's `--cache-to type=registry,scope=$BRANCH`).

---

## Section 11: Debugging Toolkit

### Q57. Container won't start, no logs — first three commands?
```
docker inspect <id> --format '{{.State.Error}}'
docker events --since 5m | grep <id>
journalctl -u docker -n 200
```

### Q58. Inspecting a running container's namespaces?
```
nsenter -t $(docker inspect -f '{{.State.Pid}}' <id>) -a
```
Gives you a shell in the container's namespaces from the host. Works even if the container has no shell (scratch).

### Q59. Profiling inside a distroless container?
Use `nsenter` from the host with host-side tools (`perf`, `bpftrace`). Or sidecar a debug container sharing the PID namespace (`docker run --pid=container:<id> nicolaka/netshoot`).

### Q60. "It works in `docker run` but fails in compose" — usual cause?
Compose creates an implicit network and DNS-resolves service names. `docker run` doesn't. Apps that hardcode `localhost` for dependencies break in compose; apps that use service names break in `docker run`.

---

## Closing Heuristics

- Pin everything: digests, base images, build tools, FROM lines.
- Measure before optimizing: pull time, build time, start time, RSS.
- Operate on the cgroup, not the process: limits, accounting, OOM scope.
- Trust nothing from the registry: verify signatures, SBOMs, provenance.
- The kernel is the contract: container behavior is kernel behavior; know your kernel.

> 20-year tip: when a vendor pitches you a "container security platform," ask them which syscalls their detection covers and what the false-positive rate was at their last F500 customer. The answer separates real products from dashboards.
