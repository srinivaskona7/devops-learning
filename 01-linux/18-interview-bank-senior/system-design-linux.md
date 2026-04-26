# System Design — Linux / Infra (Senior+)

> 10 open-ended designs. Each comes with a **6-section structured answer** that mirrors what a strong senior candidate would say on a whiteboard.

## How to use this file

For each Q, before reading the answer:

1. Spend 30-45 minutes drawing your own design.
2. Write down: scope assumptions, capacity numbers, the 3 hardest problems, and what you'd do for day-2.
3. Then compare. The point is **not** that your answer matches — it's that the dimensions you covered match.

## The 6-section answer structure

```
1. SCOPE & CONSTRAINTS    – cardinality, SLOs, what's in/out
2. HIGH-LEVEL ARCHITECTURE – boxes-and-arrows, data flow
3. KEY COMPONENTS DEEP-DIVE – the 2-3 hardest pieces, in detail
4. FAILURE MODES & MITIGATIONS – what breaks, how you survive
5. SCALABILITY & COST      – how you 10x; $ envelope
6. DAY-2 OPS               – upgrade, rollback, debug, on-call
```

---

## Q1. Design a log shipper for 100,000 servers

### 1. Scope & constraints
- **Sources**: 100k Linux hosts, mix of bare metal + VMs + containers; multiple regions.
- **Volume**: assume 5 KB avg log line, 200 lines/sec/host steady state, 10x burst → ~100 MB/s steady, 1 GB/s peak ingest globally.
- **Latency target**: p99 < 60s host → queryable; in-incident must not lag > 5 min.
- **Durability**: zero loss is **not** a goal; 99.9% is. Lossless mode optional, expensive.
- **Cost cap**: target < $X / TB ingested. Compression mandatory.

### 2. High-level architecture
```
[host agent] → [regional aggregator (Kafka)] → [normalizer/enricher] → [hot store (OS/Loki/CH)]
                                                         └─→ [cold S3 (Parquet)]
                                                         └─→ [archive after N days]
```

### 3. Deep-dive
- **Agent**: Vector / Fluent Bit / OTel collector. Local **on-disk buffer** (≥ 200 MB ring) — survives aggregator outage. Use **filesystem watch + tail-from-cursor + checkpoint** so restarts don't dup or lose. Backpressure: drop oldest of low-priority class, never block app.
- **Transport**: per-region Kafka (3 brokers/AZ, RF=3, min.insync=2). Single Kafka topic per source class; partition by host-hash. Batch + zstd. TLS + mTLS.
- **Normalize**: enrich with `hostname`, `region`, `cluster`, `env`, `service`. Sample debug logs at 1%; full sample on errors. PII scrubber.
- **Hot store**: ClickHouse / OpenSearch / Loki. Retention 7-30d.
- **Cold**: Parquet on S3 with per-day partitioning, glue catalog, queryable via Athena/Trino. Lifecycle to Glacier at 90d.

### 4. Failure modes
| Failure | Mitigation |
|---|---|
| Aggregator down | On-disk buffer at agent (~10 min runway); chaos-test it |
| Kafka full | Per-class quotas; drop debug-tier first |
| Hot store overload | Adaptive sampling on ingest; rate limit per service |
| Compromised host floods | Per-host token bucket; alert on 10x deviation |
| Schema drift breaks parsers | Contract tests; quarantine topic for unparseable lines |

### 5. Scalability & cost
- Partition by hash(host_id) — adding capacity = re-balance partitions.
- Cost dominated by hot store (RAM/IOPS). Aggressive TTL + tiered storage. Compress at every hop.
- 1 GB/s peak ≈ 86 TB/day raw → ~10-15 TB/day after zstd-3.

### 6. Day-2
- Agent upgrade is **rolling**, with canary cohort (5%) and auto-rollback on error-rate metric.
- Add a "shadow query" path so SRE can `ssh && tail` a host even when central pipe is broken.
- Documented runbook: "what to do when ingest lag > 5 min" — agent buffer status, kafka consumer lag, hot-store IO saturation.

---

## Q2. Design a multi-tenant container host

### 1. Scope & constraints
- One Linux machine running ~100 containers from N tenants. Tenants must not interfere on **CPU**, **memory**, **IO**, **network bandwidth**, **kernel**, or **filesystem**.
- Threat model: tenants are mutually distrustful; assume one will try to escape.

### 2. High-level
```
[control plane] → [kubelet/runtime] → [runc / kata / gVisor]
                                       └─ cgroup v2 (cpu/mem/io)
                                       └─ namespaces (pid/net/mnt/uts/ipc/user)
                                       └─ seccomp + apparmor + caps
                                       └─ overlayfs / btrfs subvols
```

### 3. Deep-dive
- **Resource isolation**: cgroup v2 unified hierarchy. `cpu.weight` for soft fair-share, `cpu.max` for hard cap. `memory.max` + `memory.high` for soft pressure. **`io.max`** + cgroup v2 `io.cost` controller for IO weights. `net_cls` is dead; use **eBPF tc** + per-pod bandwidth class.
- **Security boundary**: user namespaces (UID 0 in container ≠ 0 on host). Seccomp profile (deny-list at minimum, ideally allow-list). AppArmor/SELinux MAC. Drop **all** capabilities, add back only what's needed. **`no_new_privs`**. Read-only rootfs by default.
- **Stronger boundary** (when seccomp isn't enough): **Kata Containers** (microVM per pod) or **gVisor** (user-space kernel). Pay for what tenants demand.
- **Filesystem**: overlayfs upper layer per container, lower layers shared. Per-tenant quota with **project quotas** (xfs).
- **Network**: each pod in its own netns + veth into a per-tenant bridge or VXLAN; egress via NAT with per-tenant token bucket.

### 4. Failure modes
- **Noisy neighbor on IO**: cgroup `io.max` per device; monitor `pressure` (PSI).
- **Memory cliff**: avoid swap on hosts; configure `oom_score_adj`; per-tenant memory eviction prefs.
- **Kernel CVE escape**: keep kernel patched; LTS release; use Kata for high-risk tenants.
- **fork bomb**: `pids.max` per cgroup.
- **Logging fills disk**: log to ring buffer, rotate aggressively, per-pod quota.

### 5. Scalability
- 100 containers/host is conservative; can push 300-500 for stateless workloads. Limits become **pod density vs blast radius** trade.

### 6. Day-2
- Live-patching the kernel where possible (kpatch/livepatch) to avoid evictions.
- Drain-and-cordon for invasive maintenance.
- Per-tenant SLO dashboards — they should see their resource usage, not the host's.

---

## Q3. Design a high-throughput TCP load balancer

### 1. Scope & constraints
- 1M+ concurrent connections, 200 Gbps aggregate, p99 latency added < 1 ms, 99.99% availability.
- L4 only (no TLS termination here; that's a separate fleet).

### 2. High-level
```
   [BGP-anycast VIPs across PoPs]
                |
        [ECMP (DSR or NAT)]
                |
        [LB nodes — XDP / DPDK]
                |
        [backend pools w/ health checks]
```

### 3. Deep-dive
- **Data plane**: kernel bypass — **XDP/eBPF** (e.g. Katran, Cilium) or **DPDK** (Maglev-style). XDP gives kernel integration; DPDK gives ultimate throughput at cost of dedicated cores.
- **Connection hashing**: **consistent hashing** (Maglev table, ~65k entries) so backend changes don't reshuffle most flows. Hash on 5-tuple.
- **Backend health**: passive (TCP RST + RTT) + active probes. Per-backend `weight` for canary.
- **Symmetric routing**: ECMP from upstream router; LBs share state via flow-table sync OR rely on consistent hashing + same routing.
- **DSR (Direct Server Return)** when possible — return path bypasses LB, saving 50%+ bandwidth.

### 4. Failure modes
- LB node dies → BGP withdraw → ECMP rehashes → consistent hashing keeps most flows on right backend.
- Backend dies → drain via probe; existing flows allowed to finish (graceful drain).
- Synflood → SYN cookies, conntrack pressure monitoring, rate limits per src.
- Asymmetric MTU → **PMTU** broken behind ECMP — tune `tcp_mtu_probing=1`.

### 5. Scalability
- Add nodes horizontally (BGP advertises VIP from N nodes). Throughput scales with PoPs.
- Connection table is the limit per node. Use kernel bypass + huge pages + NIC RSS.

### 6. Day-2
- Drain a node by withdrawing its BGP advertisement; wait for connections to drop.
- Rolling firmware/driver upgrades — one node at a time.
- Per-VIP, per-backend metrics; flow-table size alarm; conntrack saturation alarm.

---

## Q4. Design a backup & restore for 50 PB of object storage

### 1. Scope & constraints
- 50 PB live, growing 30%/yr; >10B objects; multi-region.
- RPO 24h, RTO for a single bucket 4h, RTO for full region 7d.
- Threats: ransomware encrypts data; malicious admin deletes; bit rot; region loss.

### 2. High-level
- **Versioning + Object Lock (WORM)** for ransomware.
- **Cross-region replication** (CRR) async for region loss.
- **Point-in-time snapshots** of object indexes (manifest store).
- **Periodic full + continuous incremental** for cold off-cloud copy.

### 3. Deep-dive
- **WORM**: bucket-level Object Lock in compliance mode for sensitive classes — even root cannot delete before retention.
- **Manifest**: separate index DB (e.g. ScyllaDB) of (bucket, key, version, etag, size, ts). Snapshotted hourly. The index is what makes restore tractable at 10B objects.
- **Bit rot**: end-to-end checksums; periodic scrub job samples N objects/day, validates etag.
- **Off-cloud**: weekly Parquet manifest + sampled objects to a different cloud + tape vault. 3-2-1 rule.

### 4. Failure modes
- Ransomware: WORM + IAM least-privilege + MFA-delete on lifecycle policies.
- Malicious admin: separation of duties — delete requires 2-person approval + audit.
- Region loss: failover to replica region; restore to N+1 via CRR catch-up; document RTO budget.
- Bit rot in replica: scrub catches; auto-repair from primary.

### 5. Scalability & cost
- Tier classes: hot/warm/cold/glacier. Lifecycle moves data automatically. >80% should live cold.
- Cost dominated by storage class. Charge teams by tier to drive behavior.

### 6. Day-2
- Restore drills **quarterly** — restore a random bucket, time it, score against RTO.
- Document the "great deletion" runbook: what happens if someone runs `aws s3 rb --force`.

---

## Q5. Design a kernel-image distribution & rolling-upgrade system for 200,000 hosts

### 1. Scope
- 200k hosts, mix of bare metal + VM. Need to roll a new kernel without taking down services.
- Must support emergency CVE patches in <72h fleet-wide.

### 2. High-level
```
[image build] → [signed image registry] → [regional mirrors] → [host agent]
                                                                      ↓
                                                              [staged rollout]
```

### 3. Deep-dive
- **Image build**: reproducible, signed (cosign / minisign). SBOM published.
- **Distribution**: BitTorrent-style (e.g. Dragonfly, Kraken) or HTTP CDN with regional caches. Don't pull 200k times from origin.
- **Apply**: prefer **kexec** (warm reboot) where supported; fall back to standard reboot for kernel changes.
- **Live patching** for CVEs that can't wait — kpatch / kgraft. Signed patches, shipped via same channel.
- **Rollout**: cohorted (canary 0.1% → 1% → 10% → 50% → 100%). Each cohort waits for **green SLO window**. Auto-pause on regression.
- **Per-host orchestration**: drain, snapshot state where needed, reboot, validate, uncordon.

### 4. Failure modes
- New kernel breaks driver on subset of hardware → hardware-class cohorts; canary covers each class.
- Upgrade leaves host wedged → IPMI/BMC remote console; auto-rollback on watchdog timeout.
- Patch signing key compromise → revoke, rotate, blocklist; tamper-evident signing log.

### 5. Scalability
- Mirror tier prevents origin saturation.
- Concurrency budget per region cap = X% of hosts in flight.

### 6. Day-2
- Per-cohort SLO dashboard.
- "Stop the rollout" big red button — reachable in <10s from on-call.
- Postmortem any rollback; trend-track time-to-fleet-coverage.

---

## Q6. Design a DNS infrastructure for an internet-scale company

### 1. Scope
- Authoritative DNS for 1M+ records, 100B QPS globally, p99 < 30 ms, 100% availability.
- Recursive resolvers for internal traffic (10M QPS).

### 2. High-level
- **Authoritative**: anycast across N PoPs. Open-source NSD or PowerDNS, or proprietary. Multiple providers (avoid the Dyn outage scenario).
- **Recursive (internal)**: per-DC unbound clusters; conditional forwarding for `*.internal`.
- **Zone management**: zones in Git → CI validation → signed transfer (TSIG) to authoritatives.

### 3. Deep-dive
- **Anycast**: BGP-announce same /24 from every PoP. Pick PoP-local resolver via BGP shortest path.
- **DNSSEC**: sign zones; rotate KSK every 1-3y, ZSK every 30-90d.
- **Cache poisoning**: 0x20 randomization, source port randomization.
- **DDoS**: rate-limiting (RRL), upstream scrubbing, anycast spreads load.
- **Multi-vendor**: secondary provider; zone replication; failover by removing NS records OR weighting.

### 4. Failure modes
- Provider outage → second provider takes traffic.
- Bad zone push → CI catches 99%; emergency rollback within 60s; observability alarms on NXDOMAIN spike.
- Recursive cache poisoning → DNSSEC validation, 0x20.

### 5. Scalability
- Anycast = horizontal by PoP.
- Recursive: scale per-DC; warm caches via background prefetch.

### 6. Day-2
- Zone changes via PR with linting and policy checks (no wildcards in prod, TTLs reasonable, no orphan CNAMEs).
- Quarterly DNSSEC key rotation drill.

---

## Q7. Design an immutable infrastructure pipeline (build → deploy)

### 1. Scope
- A new git tag must result in a signed, scanned, attested image deployed to fleet within 30 min, with auto-rollback.

### 2. High-level
```
git tag → CI build → SBOM + scan → sign (cosign) → push to registry
        → policy gate (admission) → progressive rollout → SLO check → done|rollback
```

### 3. Deep-dive
- **Reproducible builds**: pinned base image, locked deps, deterministic timestamps (`SOURCE_DATE_EPOCH`).
- **Provenance**: SLSA Level 3+ attestation. Provenance signed by ephemeral CI identity (Sigstore + OIDC).
- **Policy as code**: OPA / Kyverno admission rejects unsigned, unscanned, or non-conformant images.
- **Rollout**: argo rollouts / flagger with progressive traffic shift; SLO query (latency + error rate) gates each step.
- **Rollback**: previous artifact is always deployable. Rollback is "promote previous tag," same pipeline.

### 4. Failure modes
- Compromised CI runner → ephemeral runners, OIDC-based signing, no long-lived secrets.
- Bad image passes scan → multiple scanners, runtime detection (Falco) catches what static missed.
- Registry outage → caching pull-through proxy in cluster.

### 5. Scalability
- Builds parallelize per service; image cache is the bottleneck.

### 6. Day-2
- Every deploy emits a deploy event into a change DB — correlate with incidents.
- Routine red-team exercise: try to push an unsigned image, expect rejection.

---

## Q8. Design a secrets management system for a 5,000-engineer company

### 1. Scope
- Static secrets (API keys, certs), dynamic secrets (DB creds, cloud creds), rotation, audit, per-team isolation.

### 2. High-level
- HashiCorp Vault (or cloud KMS + Vault) as the source of truth.
- Auth via OIDC (humans), workload identity (services — AWS IAM, GCP SA, K8s SA, SPIFFE).
- Sidecar / CSI / agent injects secrets into workloads at runtime; secrets never live on disk.

### 3. Deep-dive
- **No long-lived creds in Git or env files. Ever.**
- **Dynamic secrets** for DBs / cloud — Vault generates per-session creds with TTL.
- **Workload identity**: SPIFFE IDs / cloud IAM trust → Vault role; no shared bootstrap token.
- **Audit**: every read logged; logs shipped to immutable store; alarms on unusual patterns.
- **Rotation**: automated for dynamic; calendar-driven for static; "break glass" with multi-party approval.

### 4. Failure modes
- Vault outage → service can't get new secret. Mitigate with caching agent + grace period; ensure auth tokens have long enough TTL to ride through outage.
- Token leak → short TTL minimizes blast; revocation path tested.
- Insider threat → least privilege + 2-person review for sensitive paths + tamper-evident audit log.

### 5. Scalability
- Vault HA + per-region clusters; performance replication for read scale.

### 6. Day-2
- Quarterly secret-leak audit (gitleaks across repos + Slack export).
- "Lost the unseal key" runbook — Shamir shares stored offline.

---

## Q9. Design observability for a 1,000-microservice platform

### 1. Scope
- Metrics, logs, traces, profiles. Cost-bounded. Must let an on-call engineer go from page → root cause in <15 min for known patterns.

### 2. High-level
- **Metrics**: Prometheus + remote write to long-term store (Thanos / Mimir / Cortex). RED + USE.
- **Logs**: structured JSON, shipped via Vector to Loki / OpenSearch / ClickHouse.
- **Traces**: OTel SDK in apps → collector → Tempo / Jaeger. Tail-sampling for "interesting" traces.
- **Profiles**: continuous profiling (Pyroscope / Parca) — eBPF-based.
- **Glue**: exemplars (metric → trace), trace IDs in logs (trace → log), service map, single dashboard per service.

### 3. Deep-dive
- **Cardinality discipline**: no unbounded labels (no `user_id`, no `request_id` as label). Treat cardinality as cost.
- **SLOs as the lingua franca**: every service has SLO + error budget; alarms wired to budget burn rate, not raw thresholds.
- **Sampling**: head-sampling 1% baseline, tail-sample 100% on errors / slow / specific endpoint.
- **Trace ID propagation**: enforce W3C `traceparent` everywhere; log it in every log line.
- **Service catalog**: machine-readable owner, on-call, runbook, SLO link per service.

### 4. Failure modes
- Cardinality explosion → kill-switch labels at ingest; per-service quota.
- Observability outage during incident → independent stack (separate AZ, separate cloud account).
- Alert fatigue → SLO-based alerts only; hard cap on pages per team per week.

### 5. Scalability & cost
- Tiered retention: 1d high-res / 30d 1m-res / 1y 1h-res.
- Logs are usually the cost driver — sample, drop debug, compress.

### 6. Day-2
- Incident runbook templates referencing exact dashboards.
- Quarterly "observability gap" drill: pick a recent incident, ask "could we have spotted this 10 min earlier?"

---

## Q10. Design an SSH access plane for 100,000 engineers and 10M hosts

### 1. Scope
- Engineers SSH into hosts; access is auditable, time-bound, revocable; works during identity-provider partial outages; supports break-glass.

### 2. High-level
- **Short-lived SSH certificates** (signed by an SSH CA), not static keys. TTL 8-24h.
- **CA = Vault / Teleport / step-ca** + IdP (Okta/Google) for human auth.
- **Bastion / connection broker** records all sessions (with PII redaction); allows just-in-time approvals for prod.
- **Host certs** signed by host CA → no more `known_hosts` prompts.

### 3. Deep-dive
- **Cert claims**: principals = roles, valid_after/before = TTL, source-address restriction, force-command for break-glass.
- **Authorization**: policy engine (OPA) decides who gets a cert for which role.
- **Audit**: session recording (asciicast or full), command logging via PAM / sudo logs, exported to immutable store.
- **Break glass**: separate emergency CA, multi-party approval, automatic ticket + Slack + audit.

### 4. Failure modes
- IdP down → cached certs still work to TTL; emergency CA path documented.
- CA compromise → revoke cert chain; rotate; pre-distributed `revoked_keys` list as last-resort.
- Bastion compromised → session recording independent of bastion node; defense in depth.

### 5. Scalability
- Cert issuance rate: cache per-engineer cert at 8h TTL → ~12 issuances/day/engineer worst case → very low rate.
- Audit log scales separately.

### 6. Day-2
- Quarterly "everyone re-authenticates" exercise.
- Detect accounts with no SSH activity for 90d → automatically suspend.
- Annual access review: who can `sudo` on what, signed off by manager.

---

## Closing tip

You will not be asked all of these. You may be asked **one** of them, in 45 minutes, in front of three skeptical engineers. Practicing the **structure** is more valuable than memorizing the answer.
