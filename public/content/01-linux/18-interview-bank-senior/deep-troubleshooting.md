# Deep Troubleshooting — Senior Scenarios (30 Qs)

> "We see X but Y" — the classic shape of a senior interview question.
>
> Each scenario gives a **diagnosis path**: hypothesis → command → expected result → next branch.

## How to read each scenario

```text
SCENARIO   — the symptom as the user sees it
WHY HARD   — why a junior gets stuck
DIAGNOSIS  — ordered tree of investigations
ROOT CAUSE — the most common one + 1-2 others
FIX        — the immediate + the systemic
GOTCHA     — what naive answers miss
```

---

## 1. "We see TCP retransmits but the link is fine"

**Why hard.** The link being "fine" usually means `ip link` says UP and `ping` works. Retransmits live a layer higher.

**Diagnosis.**
1. `ss -ti` — per-socket retrans count, RTT, cwnd. Identifies *which* sockets retransmit.
2. `nstat -a | grep -iE 'retr|drop|fail'` — kernel-wide TCP counters since boot.
3. `ethtool -S eth0 | grep -E 'err|drop|crc|discard'` — NIC counters. CRC errors → physical/cable. RX_dropped → ring buffer full, NIC saturated, or no driver pull.
4. Check **both ends** — receiver-side drops (queue full, receive window 0) cause sender retransmits.
5. `tcpdump` a sample flow → check for **out-of-order**, **duplicate ACK**, **window 0** events.
6. Check intermediate hops with `mtr -rwc 100` — packet loss at hop N means upstream issue.
7. Check **MTU** — `ping -M do -s 1472 host` to confirm. Black-hole PMTU = retransmits without explicit drop.
8. Check **conntrack** — `cat /proc/sys/net/netfilter/nf_conntrack_count` vs `_max`; if full, new flows fail and existing flows can stall.
9. Check **buffer bloat** & qdisc — `tc -s qdisc show dev eth0` for drops on the wire.

**Root cause (common).** Microbursts overrunning NIC RX ring (ethtool -S shows `rx_no_buffer_count`). Or peer-side: small `net.core.somaxconn` / app accept queue full → `nstat ListenDrops`. Or PMTU black-hole on a tunnel.

**Fix.** Bump RX/TX ring (`ethtool -G`); enable RPS/RFS; tune `net.core.netdev_max_backlog`; fix the slow-accept app; enable PMTU probing (`net.ipv4.tcp_mtu_probing=1`).

**Gotcha.** "Link is fine" can hide receive-side drops. Always check **both ends**.

---

## 2. "Container OOMs but the host has 50% free RAM"

**Why hard.** `free -m` on the host says free; the container is being killed. People don't realize cgroup limits are independent.

**Diagnosis.**
1. `dmesg | grep -i 'killed process'` → look for `oom-kill:constraint=CONSTRAINT_MEMCG` (cgroup OOM, not host).
2. `cat /sys/fs/cgroup/<path>/memory.events` → `oom`, `oom_kill`, `max` counters.
3. `cat /sys/fs/cgroup/<path>/memory.max` → the limit.
4. `cat /sys/fs/cgroup/<path>/memory.current` → current usage.
5. `cat /sys/fs/cgroup/<path>/memory.stat` → breakdown: anon, file, kernel, slab, sock.
6. For the workload: leak? heap profile, RSS over time. Or anon_thp / huge pages overhead.
7. Check **memory.high** vs **memory.max** — `high` causes throttling; `max` causes OOM.

**Root cause.** cgroup `memory.max` reached. Often Java with `-Xmx` higher than the cgroup limit; or the app sized for host RAM, not container RAM; or page cache + dirty pages charged to cgroup pushing it over.

**Fix.** Right-size the limit; in JVM use `-XX:+UseContainerSupport` (default since 8u191); set `memory.high` slightly below `max` to get throttling before OOM; track with PSI.

**Gotcha.** Page cache **counts** toward cgroup memory. A heavy disk-reader can OOM itself.

---

## 3. "Disk usage 100% but du shows 50% free"

**Why hard.** `df` reads the filesystem superblock; `du` walks the tree. They can disagree for several reasons.

**Diagnosis.**
1. `df -h` says full. `df -i` — is it inodes, not blocks?
2. `lsof +L1` — files unlinked but still open (a process holds an FD). Space won't free until process closes. Common: a log file rotated but the process still writes to the deleted inode.
3. Mount points hiding files: `du` of `/var/log` may not see files under `/var/log/old/` if a separate FS was mounted on top hiding earlier content. `mount` to inspect.
4. Snapshots / reflinks (btrfs/zfs/xfs): `du` won't show shadowed data; FS-specific tools (`btrfs filesystem usage`, `zfs list`) needed.
5. Sparse files: `du --apparent-size` vs `du`.
6. Reserved blocks (ext4 default 5% reserved for root): `tune2fs -l` shows; explains why "free" but not free for users.

**Root cause (common).** A deleted-but-open log file; or sparse files; or btrfs metadata exhaustion.

**Fix.** Restart the holding process (or `truncate -s 0 /proc/$PID/fd/N`); rotate logs with `copytruncate`; for btrfs, `balance` metadata.

**Gotcha.** `truncate` of `/proc/PID/fd/N` to free space — surprising but legit, with caveats.

---

## 4. "App latency spikes every 60 seconds"

**Why hard.** Periodicity points to a scheduled job, but it's not in cron. Could be GC, kernel housekeeping, app's own ticker.

**Diagnosis.**
1. Check the period precisely — exactly 60s? slightly more? jittered? Use a histogram with sub-second buckets.
2. `journalctl --since '5 min ago' | grep -E '(:00 |:30 )'` — anything happening at those times.
3. Cron + systemd timers: `systemctl list-timers --all`.
4. App-level: GC logs (Java/Go runtime), background flush (kafka producer linger, prometheus scrape-aligned work).
5. Kernel: `dirty_writeback_centisecs` defaults 500cs (5s) but writeback can come in waves; `vmstat 1` will show `bo` spikes.
6. NUMA migration / CFS bandwidth — `cat /sys/fs/cgroup/<path>/cpu.stat` → `nr_throttled`, `throttled_usec`.
7. `perf record` aligned to a spike → flamegraph of the slow window.

**Root cause (common).** CFS bandwidth throttling (cgroup `cpu.max` set, app bursts above quota). Or Go GC, JVM full GC, Prometheus scrape causing cache eviction.

**Fix.** Remove CPU caps (use `cpu.weight` instead) **or** size `cpu.max` to the burst, not the average. Pre-pay GC by tuning. De-align periodic work.

**Gotcha.** "We removed CPU limits" is the right call more often than people admit. Soft fair-share usually beats hard caps.

---

## 5. "ssh hangs at `Last login:` for 20 seconds"

**Diagnosis.**
1. `ssh -vvv` — see exactly which step hangs. Usually after auth, before prompt.
2. Common culprits: reverse DNS (`UseDNS yes` in sshd_config), motd scripts, GSSAPI auth, pam_systemd creating user slice.
3. `time getent hosts <client_ip>` on the server — slow reverse DNS.
4. `pam` modules: check `/etc/pam.d/sshd` — `pam_systemd.so` can hang if D-Bus is slow.
5. `strace -f -p $(pidof sshd) -tt` during a login.

**Root cause.** Reverse DNS timeout (most common); `motd-news` fetching from internet; pam_systemd waiting on D-Bus / systemd-logind.

**Fix.** `UseDNS no` in `sshd_config`; disable motd-news; restart `systemd-logind`; ensure DNS resolvers are fast.

**Gotcha.** It's almost never SSH itself. It's the things SSH triggers.

---

## 6. "load average is 100 but CPU usage is 5%"

**Why hard.** Load avg includes **D state** (uninterruptible sleep, usually IO).

**Diagnosis.**
1. `ps -eo state,pid,cmd | awk '$1 ~ /D/'` — count D state processes.
2. `vmstat 1` — `b` column (blocked) is the smoking gun.
3. `iostat -xz 1` — `await`, `%util` per device.
4. `cat /proc/<PID>/wchan` for a sample D process — what kernel function is it stuck in.
5. Check NFS mounts (`mount | grep nfs`) — a dead NFS server pins every process touching it.
6. Check storage backend — SAN path, iSCSI, EBS throttling.

**Root cause.** Disk/network IO saturation, or a hung NFS mount, or a stuck driver.

**Fix.** Find the IO offender (`iotop -oPa`, `biolatency`); for NFS, `umount -f -l`; for cloud, check IOPS quota.

**Gotcha.** Load avg ≠ CPU. It's "things the CPU could be doing if they weren't waiting."

---

## 7. "Process is consuming 100% CPU but `top` shows it as S (sleeping)"

**Diagnosis.** `top` aggregates across an interval. A process that yields the CPU 1000x/s can show "100% CPU" while being sleeping at any sample. Check `pidstat 1` over a longer window; check `perf stat -p PID` for actual cycles.

**Root cause.** Tight syscall loop, busy-waiting on a futex, polling instead of blocking.

**Fix.** `strace -c -p PID` — see the syscall mix. Often `epoll_wait` with 0ms timeout, or `poll` returning immediately.

---

## 8. "fork() returns ENOMEM but free shows lots of memory"

**Diagnosis.** `cat /proc/sys/vm/overcommit_memory` and `/proc/sys/vm/overcommit_ratio`. With `overcommit_memory=2` (strict), kernel won't allow allocations beyond `swap + ratio% * RAM`. Also check `pids.max`.

**Root cause.** Strict overcommit + a forking app whose VSZ is huge (Java with big heap forking child uses CoW but accounting still rejects).

**Fix.** Use `vfork`/`posix_spawn`; or switch to overcommit=0 (heuristic) if appropriate; or `MADV_DONTFORK` non-essential mappings.

---

## 9. "Connections to a service work locally but fail from another host"

**Diagnosis.**
1. `ss -tlnp` — bound to `127.0.0.1` instead of `0.0.0.0`?
2. Firewall: `nft list ruleset`, cloud security group, host iptables.
3. `tcpdump` on server during attempt — does the SYN arrive? If yes, RST? If no, blocked upstream.
4. NAT/route — `ip route get <client_ip>` on server.

**Root cause.** Bind address (most common); then firewall.

---

## 10. "DNS lookups intermittently slow"

**Diagnosis.**
1. `getent hosts host` (uses NSS; matches what apps see) vs `dig +short` (skips NSS).
2. `cat /etc/resolv.conf` — multiple resolvers? `options timeout:1 attempts:2` in place?
3. `tcpdump -i any port 53` — capture during a slow query.
4. systemd-resolved? `resolvectl status` — check fallback.
5. Glibc 2.x bug: parallel A + AAAA queries on same socket; if one resolver drops AAAA, you wait 5s. Set `single-request-reopen` or `single-request`.

**Root cause.** AAAA queries dropped or slow; resolver list with a dead first entry; container `/etc/resolv.conf` pointing at a dead in-cluster resolver.

**Fix.** Add `options single-request-reopen timeout:1`; ensure first resolver responsive; consider local caching resolver (systemd-resolved, dnsmasq, unbound).

---

## 11. "`tar` extraction is 100x slower than expected"

**Diagnosis.** `iostat -xz 1` shows tiny IOs. Many small files = metadata-bound, not throughput-bound. Check `df -i`, FS journal mode, sync mounts.

**Root cause.** ext4 with `data=journal`, or `sync` mount, or mounted with `commit=0`. Or extracting to NFS.

**Fix.** `tar` with `--one-top-level` to bulk; mount with `noatime`, `nodiratime`; use modern FS (xfs/btrfs handle metadata better); disable sync.

---

## 12. "We deployed a new image and CPU usage doubled. Code didn't change."

**Diagnosis.**
1. Diff the image: `dive`, `docker history`. Base image bumped?
2. Library version diff — `ldd`, `dpkg -l`.
3. Compiler/runtime change (Go 1.20 → 1.21 GC behavior, glibc malloc tuning).
4. `perf top -p $PID` — different hot functions vs old image?

**Root cause.** Often a base-image refresh pulled in a new glibc / openssl / runtime.

**Fix.** Pin base image by digest, not tag.

---

## 13. "Kernel says 'sched: RT throttling activated'"

**Diagnosis.** A `SCHED_FIFO`/`SCHED_RR` task ran past `sched_rt_runtime_us` (default 950000 of 1000000us). Kernel throttles to prevent system lockup.

**Root cause.** Misconfigured realtime app (audio engine, RT control loop) busy-looping.

**Fix.** Yield in the loop; or raise the cap (`/proc/sys/kernel/sched_rt_runtime_us`); or use `SCHED_DEADLINE` properly.

---

## 14. "Backup script that worked yesterday now fails with `Argument list too long`"

**Diagnosis.** `getconf ARG_MAX` (usually 2 MB). Glob expanded to too many args. `ls *.log | wc -l`.

**Fix.** Use `find ... -exec ... +` or `find ... -print0 | xargs -0 ...`. Never `cmd *` on directories you don't control.

---

## 15. "iperf shows 9 Gbps but our app does 200 Mbps over the same link"

**Diagnosis.**
1. Number of parallel flows — single-stream TCP is RTT-bound; iperf may use parallel.
2. App-level: small writes (no Nagle/cork), tiny send buffer, blocking IO with low concurrency.
3. TCP buffers: `net.ipv4.tcp_rmem`, `tcp_wmem`. Auto-tuning enabled?
4. CPU: pin a `perf` on the app; is it CPU-bound on serialization/encryption?
5. `ss -ti` — `cwnd`, `rcv_space`, `delivery_rate`.

**Root cause.** App pattern (tiny syscalls, missing pipelining), or TLS CPU bottleneck, or BBR not enabled across high-RTT.

**Fix.** Batch app writes; use `TCP_CORK`; tune buffers; consider BBR (`net.ipv4.tcp_congestion_control=bbr`).

---

## 16. "K8s pod restarts every 10 minutes with no log output"

**Diagnosis.**
1. `kubectl describe pod` — last termination reason. OOMKilled? Liveness probe fail?
2. `kubectl logs --previous` — crash logs from previous container.
3. dmesg on the node for OOM.
4. Liveness probe pattern: probe takes longer than `timeoutSeconds`? Probe path right?
5. App-level: deadlock that hangs liveness check.

**Root cause.** Liveness probe timing out under load (most common); OOM (second).

**Fix.** Use **startup probe** for slow starters; longer `timeoutSeconds`; separate liveness (cheap) from readiness (deeper).

---

## 17. "Process can read /etc/shadow as non-root"

**Diagnosis.** `ls -l /etc/shadow` (should be `0640 root:shadow`); `getcap` on the binary; check setuid bit; check ACLs (`getfacl`); SELinux/AppArmor relabel.

**Root cause.** A `setcap CAP_DAC_READ_SEARCH+ep` on a tool, or a misplaced ACL.

**Fix.** Remove the cap; audit periodically (`getcap -r /`).

---

## 18. "Two systemd timers fire at midnight; one always loses"

**Diagnosis.** `systemctl list-timers --all` shows both at 00:00:00. Without `RandomizedDelaySec`, they race for IO/CPU at the same instant.

**Fix.** `RandomizedDelaySec=10m`; or stagger explicitly. Same for cron — never schedule everything at `0 0 * * *`.

---

## 19. "Some HTTP requests time out, but not others, even to the same backend"

**Diagnosis.**
1. Check **per-backend instance** — load balancer pinning sticky to one bad pod?
2. Conntrack table on LB / NAT — full?
3. ephemeral port exhaustion on client (`net.ipv4.ip_local_port_range`, lots of TIME_WAIT).
4. TLS session resumption disabled → handshake CPU hot.
5. SYN backlog full on server (`ss -lnt` Send-Q vs Recv-Q).

**Root cause.** Often ephemeral port exhaustion under high connection rate.

**Fix.** Raise port range; reuse connections (HTTP keepalive, connection pool); enable `tcp_tw_reuse=1` on clients.

---

## 20. "Filesystem went read-only with no warning"

**Diagnosis.** `dmesg | grep -i 'remount.*read-only'`. ext4 default `errors=remount-ro`. The kernel detected metadata corruption.

**Root cause.** Underlying device error (cable, controller, cloud volume failure). `smartctl -a`, cloud console.

**Fix.** Reboot to fsck; replace device; root cause the corruption (disk dying, controller, abrupt power loss).

---

## 21. "Cron job didn't run, but it's in the crontab"

**Diagnosis.** `grep CRON /var/log/syslog` (or journalctl). Crontab without trailing newline; PATH minimal in cron env (`/usr/bin:/bin`); MAILTO not set so silent failures; SELinux denying; `%` in command not escaped.

**Fix.** Always set explicit PATH at top of crontab; redirect output (`>>/var/log/myjob.log 2>&1`); test with `* * * * *` first.

---

## 22. "After kernel upgrade, app crashes with SIGSYS"

**Root cause.** Seccomp filter denying a syscall the new glibc started using (`clone3`, `faccessat2`, `close_range`).

**Fix.** Update seccomp filter; or downgrade glibc; or rebuild the seccomp policy from a real workload trace (`strace` → allow set).

---

## 23. "I/O latency p99 is 50ms but disk is 'idle'"

**Diagnosis.** `iostat -xz 1` shows low %util but high `await`. Cloud disk **bursting credits exhausted** (AWS gp2/gp3, GCP balanced PD); the disk is metering you.

**Fix.** Move to provisioned IOPS class; or pre-warm; or reduce IO; or ensure burst credits replenish.

---

## 24. "Service is slow only on one host out of 30"

**Diagnosis.** Compare hosts: kernel version, NIC firmware, disk model, cgroup limits, neighbor noisy workloads, dmesg differences (CPU throttling, MCE, ECC errors), SMI latency (`turbostat`).

**Root cause.** Hardware degradation (failing disk increasing latency), or a single misconfigured host (different sysctl), or co-tenant.

**Fix.** Identify outlier; cordon; replace.

---

## 25. "Logs show TLS handshake failures only after a few hours uptime"

**Diagnosis.** Certificate not the issue (would fail immediately). FD leak? `lsof -p PID | wc -l` over time. Conntrack? Entropy? Check `/proc/sys/kernel/random/entropy_avail` (less of an issue on modern kernels with CRNG).

**Root cause.** FD exhaustion preventing accept of new TLS connections.

**Fix.** Raise `LimitNOFILE`; fix the leak.

---

## 26. "Noisy-neighbor: one container crushes others' performance"

**Diagnosis.** `systemd-cgtop`; per-cgroup PSI (`cat /sys/fs/cgroup/<path>/cpu.pressure`, `io.pressure`, `memory.pressure`); check `cpu.weight` set per workload; `io.max` set per device; LLC contention via `perf c2c` / RDT (Intel CAT).

**Fix.** Set IO weights via cgroup v2 io.cost; CPU weights; consider Intel CAT for L3 cache partitioning.

---

## 27. "TIME_WAIT sockets piling up — hundreds of thousands"

**Diagnosis.** `ss -tan state time-wait | wc -l`. Default `tcp_max_tw_buckets` 65k. Above that, kernel logs "TCP: time wait bucket table overflow."

**Root cause.** Short-lived connections from the active-close side. Lots of `curl` / API calls without keepalive.

**Fix.** Reuse connections (keepalive); on **client** only, `tcp_tw_reuse=1`; raise bucket size; switch role (let server be active-close).

**Gotcha.** Don't touch `tcp_tw_recycle` — it was removed in 4.12 because it broke NAT.

---

## 28. "After enabling THP (transparent huge pages), database latency p99 doubled"

**Root cause.** Databases (Mongo, Redis, postgres) often advise disabling THP because **defrag** causes long stalls.

**Fix.** `echo madvise > /sys/kernel/mm/transparent_hugepage/enabled`; or `never`. Set in tuned profile / GRUB.

---

## 29. "Ephemeral pod IP showing in audit log for hours after pod deletion"

**Diagnosis.** Log enrichment uses cached pod-IP map. Stale cache.

**Fix.** Reduce cache TTL; or correlate by trace ID + timestamp + pod UID rather than IP.

---

## 30. "Production cluster works; staging cluster (identical config) doesn't"

**Diagnosis.** "Identical config" is almost never identical. Diff:
- kernel version, distro packages
- IAM / cloud roles (often the bug)
- Network policies, security groups
- DNS — different VPC resolver, search domains
- Resource sizes (small staging exposes timeouts)
- Data — staging has different/fewer rows
- Time skew (NTP drift)

**Fix.** GitOps the cluster spec; routine "diff prod vs staging" report; ban "snowflake" config edits.

**Gotcha.** "It works in prod, fails in staging" usually means staging is the more honest environment — you got lucky in prod.

---

## Pattern: how to talk through any troubleshooting question

1. **Restate**: "So what we're seeing is X, and Y."
2. **Hypothesize 2-3 categories** out loud: "This could be A, B, or C."
3. **Order by likelihood and cheapness to test.**
4. **Name what each result would tell you** — this is the senior signal.
5. **Mention what you'd do to make it observable next time.**
