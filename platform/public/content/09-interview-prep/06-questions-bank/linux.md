# Linux Q&A Bank

These questions are the ones I've actually been asked / would ask for SRE/Platform/DevOps roles. Linux fundamentals are non-negotiable — if you can't explain processes, file descriptors, or how `ps` gets its data, you fail the screen.

## How to use

Say each answer out loud. Cap your first attempt at 60 seconds. If you can't finish in 60s, you don't know it well enough — read, then re-attempt 24h later. Push yourself with "why" follow-ups: "why does fork() use copy-on-write?", "why is `kill -9` dangerous?".

---

## Processes & Signals

**Q1. What's the difference between a process and a thread?**
A process has its own address space, file descriptor table, and PID. Threads within a process share address space and FDs but have separate stacks and registers. Linux implements both via `clone()` — threads are just processes that share more resources. Context switches between threads are cheaper because the MMU doesn't need to flush.

**Q2. Walk me through what happens when you run `ls` in bash.**
Bash forks a child (`fork()`/`clone()`), the child calls `execve("/bin/ls", argv, envp)` which replaces its memory image with the ls binary. Bash `wait()`s on the child PID. The kernel loads the ELF, resolves dynamic libraries via ld.so, runs `_start` → `main`. On exit, the child becomes a zombie until bash reaps it.

**Q3. What is a zombie process and how do you fix one?**
A zombie is a terminated process whose parent hasn't called `wait()` to reap its exit status. It holds a PID slot but no memory. You can't kill a zombie — you must signal the parent (typically with `SIGCHLD`) or kill the parent so init/systemd reaps it.

**Q4. Difference between SIGTERM and SIGKILL?**
SIGTERM (15) is catchable — the process can install a handler for graceful shutdown (flush buffers, close connections). SIGKILL (9) is uncatchable; the kernel terminates the process immediately. Always send SIGTERM first; SIGKILL leaves resources in inconsistent states (open files, locks, partial writes).

**Q5. What's the difference between `fork()` and `exec()`?**
`fork()` creates a copy of the current process (copy-on-write). `exec()` replaces the current process image with a new program. `fork()` returns twice (0 in child, child PID in parent). Shells use fork+exec to run commands without replacing themselves.

**Q6. What is PID 1 and why is it special?**
PID 1 is init (systemd, openrc, sysvinit). It's the ancestor of all processes, reaps orphans, and if it dies the kernel panics. In containers, your entrypoint is PID 1 — which means it must handle SIGTERM and reap zombies, or use a tini-style init shim.

**Q7. How does nice/renice affect scheduling?**
Nice values range -20 (highest priority) to +19 (lowest). Default is 0. Only root can set negative nice. The CFS scheduler uses nice as a weight — nice +10 gets ~10x less CPU than nice 0. `renice 5 -p 1234` adjusts a running process.

**Q8. What is `/proc/<pid>` and what's in it?**
A virtual filesystem exposing kernel state per-process. Key files: `status` (memory, state), `cmdline` (args), `environ` (env vars), `fd/` (open file descriptors as symlinks), `maps` (memory regions), `stat` (raw scheduling stats). Tools like `ps`, `top`, `lsof` parse `/proc`.

---

## Filesystems

**Q9. Explain the inode.**
An inode stores file metadata: permissions, owner, size, timestamps, and pointers to data blocks. The filename is in the directory entry, not the inode — that's why hard links work (multiple names → one inode). Run out of inodes and you can't create files even with free disk space.

**Q10. Hard link vs symlink?**
Hard link: another directory entry pointing to the same inode. Same filesystem only, can't link directories. Symlink: a small file containing a path string. Crosses filesystems, can dangle if target deleted, has its own inode.

**Q11. What does `chmod 755` mean?**
Owner: rwx (4+2+1=7), group: r-x (4+1=5), others: r-x. Common for executables and directories. For dirs, x means "can enter/traverse", r means "can list contents".

**Q12. Difference between umask and chmod?**
chmod sets permissions on existing files. umask is a bitmask subtracted from default permissions (666 for files, 777 for dirs) when files are created. Common umask 022 → new files get 644, new dirs get 755.

**Q13. What are the standard mount options you'd use for /var/log?**
`noexec,nosuid,nodev` — logs shouldn't have executables, setuid bits, or device nodes. Add `noatime` to skip access-time updates and reduce write amplification.

**Q14. Difference between ext4, xfs, btrfs?**
ext4: mature, journaling, default on most distros. xfs: better for large files and parallel I/O, default on RHEL. btrfs: copy-on-write, snapshots, subvolumes, but less mature for production DBs. Pick xfs for log/metric workloads, ext4 for general-purpose.

**Q15. How do you find what's filling up a disk?**
`df -h` to find the full mount, then `du -sh /path/* | sort -h` (or `ncdu` interactively). Check open-but-deleted files with `lsof | grep deleted` — common cause of "df shows full but du doesn't agree".

**Q16. Explain bind mount.**
`mount --bind /src /dst` makes /src visible at /dst — same inodes, two paths. Used heavily by containers for volume mounts. Unlike symlinks, bind mounts work transparently for chrooted processes.

---

## Networking

**Q17. Walk through what happens when you `curl https://example.com`.**
DNS resolution (resolver → recursive → authoritative). TCP 3-way handshake to resolved IP:443. TLS handshake (ClientHello, certificate validation, key exchange). HTTP request sent. Response received. TCP FIN. curl writes body to stdout.

**Q18. Difference between TCP and UDP?**
TCP: connection-oriented, reliable, ordered, congestion-controlled, ~20-byte header. UDP: connectionless, unreliable, unordered, 8-byte header, low overhead. Use UDP for DNS, video, gaming where loss < latency. Use TCP for everything else by default.

**Q19. What's in a TCP 3-way handshake?**
Client SYN → server SYN-ACK → client ACK. Establishes initial sequence numbers and confirms bidirectional connectivity. Connection is ESTABLISHED after the third packet.

**Q20. How do you check what's listening on port 8080?**
`ss -tlnp | grep 8080` (modern) or `netstat -tlnp | grep 8080` (legacy). `lsof -i :8080` also works. `-p` shows the owning process.

**Q21. Difference between iptables and nftables?**
iptables: legacy, separate tables (filter, nat, mangle), one rule per line evaluated linearly. nftables: unified, faster (uses sets and maps), single binary `nft`, replaces iptables/ip6tables/arptables. Modern distros default to nftables but provide iptables-nft compatibility shim.

**Q22. What's a SYN flood and how do you mitigate it?**
Attacker sends many SYNs without completing handshake; server's half-open queue fills up. Mitigations: SYN cookies (`net.ipv4.tcp_syncookies=1`), increase `tcp_max_syn_backlog`, rate-limit at firewall, use SYN proxies upstream.

**Q23. Explain DNS resolution order on Linux.**
`/etc/nsswitch.conf` defines source order — typically `files dns` (so `/etc/hosts` first, then DNS). DNS uses `/etc/resolv.conf` (or systemd-resolved at 127.0.0.53). Stub resolver → configured nameservers → recursive resolution.

**Q24. What does `traceroute` actually do?**
Sends packets with incrementing TTL starting at 1. Each hop decrements TTL; when TTL=0 the router sends back ICMP TIME_EXCEEDED revealing its IP. Builds a hop-by-hop path. UDP by default on Linux (high port), ICMP on Windows.

**Q25. Difference between a bridge, a VLAN, and a VXLAN?**
Bridge: L2 switch in software, joins interfaces in same broadcast domain. VLAN: tags frames with 12-bit ID for segmentation on same physical L2. VXLAN: encapsulates L2 frames in UDP for L3 transport, 24-bit VNI, used in cloud overlays (Kubernetes CNI).

---

## Systemd

**Q26. What is systemd and why did it replace SysV init?**
A system and service manager. Replaced SysV for: parallel startup (faster boots), socket activation, dependency resolution, cgroup-based process tracking, journal logging, unified config (unit files vs shell scripts).

**Q27. Walk through a systemd unit file.**
`[Unit]`: description, dependencies (After, Requires). `[Service]`: ExecStart, Restart policy, User, Environment. `[Install]`: WantedBy=multi-user.target (when enabled). Place in `/etc/systemd/system/foo.service`, `systemctl daemon-reload`, `systemctl enable --now foo`.

**Q28. Difference between Requires=, Wants=, After=?**
After= is ordering only (start B after A, but failure of A doesn't affect B). Requires= is hard dependency (if A fails, B is stopped). Wants= is soft dependency (try to start A but don't fail if it doesn't). Use Wants+After for most cases.

**Q29. How do you view logs for a service?**
`journalctl -u foo.service -f` (follow), `--since "10 min ago"`, `-p err` (priority), `-b` (current boot). Logs are structured JSON internally; query by fields: `journalctl _PID=1234`.

**Q30. What's a systemd timer and when would you use it over cron?**
Timer units schedule service units. Advantages over cron: dependency-aware, logs to journal, can run on-failure handlers, supports OnBootSec/monotonic schedules, randomized delays. Use cron for one-liners and timers for anything that needs observability.

**Q31. How does systemd track processes?**
Each unit gets its own cgroup. All forked children inherit the cgroup, so systemd reliably tracks the entire process tree (unlike SysV which lost track of double-forked daemons). `systemctl status` shows the cgroup tree.

---

## Performance & Debugging

**Q32. A server is slow. Walk me through your investigation.**
USE method: Utilization, Saturation, Errors. `uptime` (load avg), `vmstat 1` (CPU/IO/swap), `iostat -xz 1` (disk), `mpstat -P ALL 1` (per-CPU), `pidstat 1` (per-process), `free -h` (mem), `ss -s` (socket stats), `dmesg -T` (kernel errors). Then narrow to top offender with `top`/`htop`.

**Q33. Load average is 20 on an 8-core box. What does that mean?**
Load avg = average runnable + uninterruptible-sleep processes over 1/5/15 min. 20 on 8 cores = 12 processes waiting (CPU-bound) or stuck in D-state (I/O-bound). Check with `ps -eo state,pid,comm | grep -E '^[RD]'`. D-state often means slow disk or NFS.

**Q34. How do you trace syscalls of a running process?**
`strace -p <pid> -f -e trace=network` (filter by category). Adds significant overhead — use sparingly. For production-safe tracing use `bpftrace` or `perf trace`.

**Q35. What does `top`'s %wa mean?**
I/O wait — CPU is idle waiting for disk/network I/O to complete. High %wa with low CPU usage = storage bottleneck. Confirm with `iostat -xz 1` and look at `%util` and `await`.

**Q36. How do you find which process opened a file?**
`lsof <path>` or `fuser -v <path>`. For a deleted-but-open file: `lsof | grep deleted`. Recover content from `/proc/<pid>/fd/<n>`.

**Q37. OOM killer fired. How do you investigate?**
`dmesg -T | grep -i oom` — shows victim PID, RSS, oom_score. Check `journalctl -k` for kernel messages. Long term: set memory limits via cgroups/systemd, tune `vm.overcommit_memory`, add swap, fix the leak.

**Q38. What is THP (Transparent Huge Pages) and why disable it?**
THP groups 4KB pages into 2MB pages to reduce TLB misses. But it can cause latency spikes during compaction, especially with Redis/MongoDB/Java heaps. Disable with `echo never > /sys/kernel/mm/transparent_hugepage/enabled` for latency-sensitive workloads.

**Q39. What's the difference between RSS, VSZ, and PSS?**
VSZ: virtual size (everything mapped, including unloaded). RSS: resident set size (actually in RAM, including shared). PSS: proportional set size (shared pages divided by sharers — most accurate for "real" usage). Use PSS to sum without double-counting.

**Q40. Explain copy-on-write in fork().**
Both parent and child initially share the same physical pages, marked read-only. On a write, the kernel traps the page fault and copies the page to a new physical frame. Saves memory when the child immediately execs.

---

## Shell & Scripting

**Q41. Difference between `>`, `>>`, `2>&1`?**
`>` truncate-redirect stdout. `>>` append stdout. `2>&1` redirect stderr to wherever stdout currently points. Order matters: `cmd > file 2>&1` redirects both; `cmd 2>&1 > file` only redirects stdout.

**Q42. What does `set -euo pipefail` do?**
`-e` exit on any error. `-u` error on unset variable. `-o pipefail` make a pipeline fail if any stage fails (not just the last). Defensive default for production scripts.

**Q43. Difference between `$@` and `$*`?**
Both expand to all positional args. `"$@"` expands each arg as a separate quoted string (preserves spaces). `"$*"` joins all args into one string with IFS separator. Almost always use `"$@"`.

**Q44. How do you debug a bash script?**
`bash -x script.sh` or add `set -x` inside. Use `set +x` to disable. `PS4='+ $LINENO: '` for cleaner trace. For silent failures, `set -e` and check exit codes.

**Q45. What does `trap 'cleanup' EXIT` do?**
Registers a signal handler — runs `cleanup` function whenever the script exits (normal, error, signal). Used for guaranteed cleanup of temp files, locks, child processes.

---

## Security & Permissions

**Q46. What is setuid and why is it dangerous?**
A bit on an executable that makes it run as the file owner (often root). Used for `passwd`, `sudo`. Dangerous: any vulnerability becomes privilege escalation. Find them: `find / -perm -4000 -type f`.

**Q47. Explain capabilities vs setuid.**
Capabilities (CAP_NET_BIND_SERVICE, CAP_SYS_ADMIN, etc.) decompose root into discrete permissions. A binary can have just CAP_NET_BIND_SERVICE instead of full root. Set with `setcap cap_net_bind_service=+ep /usr/bin/foo`.

**Q48. What's the difference between sudo and su?**
`su -` becomes another user (full shell). `sudo` runs a single command as another user (default root) with logging and policy in `/etc/sudoers`. sudo is auditable and granular; su is binary.

**Q49. What does `chroot` do and why isn't it security?**
chroot changes the apparent root directory for a process. Not a security boundary — root inside can escape via mknod, pivot_root tricks. Use namespaces + cgroups (containers) for actual isolation.

**Q50. Explain Linux namespaces.**
Isolation primitives: PID (separate process tree), NET (separate interfaces/routes), MNT (separate mount table), UTS (hostname), IPC (shared memory), USER (UID mapping), CGROUP (cgroup view). Containers = combination of namespaces + cgroups + capabilities + seccomp.

**Q51. What is cgroups v2 and how does it differ from v1?**
cgroups limit resource use (CPU, memory, IO, PIDs). v1: separate hierarchy per controller, complex. v2: unified hierarchy, simpler model, better IO accounting, required by modern Kubernetes (PSI metrics, swap accounting). systemd uses v2 by default on modern distros.

**Q52. What's an SELinux context and how do you debug AVC denials?**
SELinux labels every process and file with a context (`user:role:type:level`). Policies allow/deny based on labels. Denials logged as AVC in `/var/log/audit/audit.log`. Use `ausearch -m avc -ts recent` and `audit2allow` to generate policy fixes.

---

## Boot & Init

**Q53. Walk me through the Linux boot process.**
BIOS/UEFI POST → bootloader (GRUB) reads config → loads kernel + initramfs into memory → kernel decompresses, initializes drivers, mounts initramfs as root → runs init in initramfs (mounts real root via UUID) → switch_root → exec /sbin/init (systemd) → systemd starts target chain.

**Q54. What's in initramfs and why do we need it?**
A compressed cpio archive with minimal userspace + kernel modules needed to mount the real root (e.g., LVM, RAID, encrypted volumes). Without it, the kernel can't access roots that need userspace setup.

**Q55. How do you boot into single-user mode?**
At GRUB, edit kernel line, append `single` or `systemd.unit=rescue.target`. Boots to a root shell without networking/services for recovery.

---

## Misc

**Q56. What's the difference between `apt`, `apt-get`, and `dpkg`?**
dpkg: low-level (install/remove .deb, no dependency resolution). apt-get: classic high-level (resolves deps from repos). apt: newer user-friendly wrapper combining apt-get and apt-cache with progress bars. Use apt interactively, apt-get in scripts.

**Q57. How do you persist a kernel parameter across reboots?**
Edit `/etc/sysctl.d/99-custom.conf`, add `vm.swappiness=10`, run `sysctl --system`. For boot-time params, edit `/etc/default/grub` GRUB_CMDLINE_LINUX, run `update-grub`.

**Q58. What is /dev/shm?**
A tmpfs (RAM-backed) filesystem for shared memory. Default size 50% of RAM. Used by POSIX shm_open(), some databases, and apps needing fast IPC.
