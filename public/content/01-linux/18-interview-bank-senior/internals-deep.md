# Linux Internals — Deep Questions (40 Qs)

> Senior interviewers don't want trivia. They want **mental models** that hold up under pressure.
>
> For each question: a 1-paragraph answer + the gotcha or follow-up they'll throw at you.

---

## Memory & VM

### 1. Page cache vs buffer cache — what's the difference today?

Historically distinct: **page cache** held file-data pages; **buffer cache** held block-device blocks. Since Linux 2.4 they were unified: file data goes into the page cache; raw block IO uses **buffer heads** that point at page-cache pages. So `free -m`'s `buffers` is a small layer of metadata buffer heads; `cached` is real file data. You should treat them as one thing for capacity reasoning.

**Gotcha.** "Available" memory = `MemFree` + reclaimable cache + reclaimable slab. That's the number that matters, not "free."

### 2. What happens (in kernel terms) when you `read()` a file?

VFS dispatches to the filesystem's `read_iter`. Filesystem checks the page cache (radix/xarray). On hit: copy_to_user from cache page. On miss: allocates a page, issues bio to block layer, scheduler queues it on the device, IRQ on completion wakes the waiter, copy_to_user. Inode `atime` updated (unless `noatime`). Readahead kicks in for sequential patterns.

### 3. What's copy-on-write (CoW) and where does it appear?

A shared page is marked read-only; on write, the kernel allocates a private copy. Used by: `fork()` (parent and child share pages until either writes), private anonymous mappings, `mmap` of files with MAP_PRIVATE, btrfs/zfs file blocks, snapshots, overlayfs upper layer.

**Gotcha.** A `fork()` of a 10 GB process is "free" — until either side starts writing. That's why JVM forks of huge heaps look fine until they don't.

### 4. fork() vs vfork() vs clone() vs posix_spawn() vs clone3()

- `fork()`: full process duplicate via CoW.
- `vfork()`: child shares parent's address space; parent suspended until child execs/exits. Faster but dangerous; mostly used internally.
- `clone()`: low-level primitive backing all the above; flags select what to share (VM, FS, FD table, signal handlers, namespaces).
- `posix_spawn()`: portable atomic fork+exec; on Linux, often optimized to vfork+exec; safer than DIY fork.
- `clone3()`: modern struct-based variant supporting new flags (`CLONE_INTO_CGROUP`, `set_tid`).

### 5. What's vDSO?

Virtual dynamic shared object — a small ELF the kernel maps into every process. Lets userspace call certain "syscalls" (`gettimeofday`, `clock_gettime`, `getcpu`) without entering the kernel. Massive speedup for time-heavy workloads.

### 6. What is the OOM killer's scoring algorithm?

`/proc/PID/oom_score` is computed from RSS + swap usage, biased by `oom_score_adj` (-1000 to +1000). The kernel kills the highest score in the failing memory cgroup (or globally). Children of the killed process get score boost. `oom_score_adj=-1000` makes a process unkillable.

**Gotcha.** Newer kernels prefer killing the **biggest single offender**, not "everything." Set `oom_score_adj` on critical processes (e.g., `sshd`, `systemd-journald`).

### 7. Anonymous vs file-backed memory

Anonymous = no file behind it (heap, stack, MAP_ANONYMOUS). Backed by swap if available. File-backed = pages tied to a file (executables, libraries, mmap'd files); reclaimed by writing dirty pages out, then dropping clean pages — no swap needed.

### 8. What is THP and when does it hurt?

Transparent Huge Pages combine 4 KB pages into 2 MB pages, reducing TLB pressure. Helps memory-bandwidth-bound workloads. Hurts workloads with **mostly cold memory + occasional small writes** because the **defrag** thread (`khugepaged`) takes long page-fault stalls. Common DB/Redis advice: `madvise` or `never`.

### 9. What's the difference between `MADV_DONTNEED` and `MADV_FREE`?

`DONTNEED`: pages returned to kernel **immediately**; next access re-faults to zero (anonymous) or file (file-backed).
`FREE`: lazy — kernel may reclaim, but if you touch the page first, original contents stay. Lower overhead, weaker semantics. Used by modern allocators (jemalloc, glibc 2.28+).

### 10. Slab allocator — what is it?

Kernel's allocator for small fixed-size objects (inodes, dentries, sockets). Each object size has a cache; reduces fragmentation. View with `slabtop` or `/proc/slabinfo`. SLAB / SLUB / SLOB are implementations; SLUB is default.

---

## Processes, Signals, Scheduling

### 11. fork+exec — step by step

1. Parent calls `fork()`. Kernel creates child PCB, marks pages CoW, returns 0 to child / pid to parent.
2. Child calls `execve(path)`. Kernel: validates binary, builds new mm_struct, parses ELF, maps text/data, sets up stack with argv/envp, jumps to entry point.
3. Old address space is torn down before the new one is loaded. PID and parent stay the same; FDs survive (unless CLOEXEC).

### 12. What does a process **state** of D really mean?

"Uninterruptible sleep" — sleeping in the kernel **with signals blocked**. Usually waiting on IO that the kernel believes will return imminently (disk, NFS). The process cannot be killed (even SIGKILL) until the wait returns. Long D state = something downstream is wrong.

### 13. What's a zombie and why can't `kill -9` reap it?

A zombie is a child that has exited but whose exit status the parent has not yet read with `wait()`. The kernel keeps the process descriptor (PID + exit status) so the parent can collect it. `kill` doesn't apply — there's no live thread. Fix: signal the parent (`SIGCHLD`) or kill the parent so init reaps the zombie.

### 14. Signal-safe functions — what makes a function async-signal-safe?

It must be reentrant — safe to call from a signal handler that interrupted itself or a sibling. POSIX defines a strict list (`write`, `read`, `_exit`, `signal`, `kill`, etc.). Notably **NOT** safe: `printf`, `malloc`, `pthread_mutex_lock`. Common bug: `printf` from a signal handler deadlocks if the main thread held stdio's lock.

**Tip.** The classic safe pattern: in handler, `write()` a byte to a self-pipe; main loop reads it.

### 15. SIGKILL vs SIGSTOP — what makes them special?

Both are uncatchable, unblockable, unignorable. SIGKILL terminates immediately; SIGSTOP pauses immediately. Cannot be intercepted because the kernel handles them itself.

### 16. CFS scheduler — how does it pick the next task?

Completely Fair Scheduler tracks each task's `vruntime` (virtual runtime, weighted by nice). Picks the task with smallest vruntime from a red-black tree. Goal: equal CPU shares, weighted by nice value. CGroup `cpu.weight` (cgv2) / `cpu.shares` (cgv1) control group-level weight.

### 17. CFS bandwidth control — `cpu.max` semantics

A cgroup is granted `quota` per `period` (default 100 ms period). Once quota is exhausted, all tasks in the group are throttled until next period. Throttling can cause large p99 latency in low-average-but-bursty workloads.

### 18. SCHED_FIFO / SCHED_RR / SCHED_DEADLINE

Real-time policies; preempt all CFS tasks.
- FIFO: runs until it yields/blocks/preempted by higher prio.
- RR: like FIFO but with timeslice.
- DEADLINE: EDF scheduler with (runtime, deadline, period) tuple — true bounded latency.

Misconfigured RT can starve the system → kernel RT throttling (`sched_rt_runtime_us`).

### 19. Context switch — what actually happens?

Save current task's CPU registers + FPU state into its task_struct, switch mm (load new CR3 / page tables, flush TLB unless PCID/ASID), restore new task's registers, jump. Cost: ~1-3 μs direct + cache cold-miss costs after. Visible as `vmstat 1`'s `cs` column.

### 20. What is a thread, in Linux?

In Linux, a thread is a process that shares mm/files/signals with siblings via `clone(CLONE_VM | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD)`. Each has its own kernel `task_struct`. POSIX threads (NPTL) are 1:1 with kernel tasks. There's no "lightweight thread" abstraction in the kernel.

---

## IPC, Synchronization

### 21. futex vs mutex — what's a futex?

A **futex** (fast userspace mutex) is a kernel primitive that lets userspace synchronization libraries (pthread mutex, glibc, Go runtime) park/wake threads only when contended. Uncontended path is pure userspace atomic op (no syscall). On contention, a `futex(WAIT)`/`futex(WAKE)` syscall is made. A pthread_mutex is built on a futex.

### 22. eventfd, signalfd, timerfd, epoll — why these exist

To unify asynchronous primitives onto a single `epoll_wait` loop. Instead of mixing signal handlers, alarms, and IO, you read everything as file-descriptor events. The unix-philosophy answer to event loops.

### 23. epoll vs select vs poll

`select`: O(N), bitmask of FDs, capped at FD_SETSIZE (1024). `poll`: O(N), arbitrary count. `epoll`: O(1) per event, persistent kernel state, edge- or level-triggered. For >>1k FDs, only epoll is viable.

`io_uring` is the modern successor — async system calls, no per-op syscall, supports much more than IO multiplexing.

### 24. SysV vs POSIX IPC

SysV: `msgget`/`shmget`/`semget` — older, kernel-resource-keyed, harder to clean up (`ipcs -a`). POSIX: `mq_open`, `shm_open`, `sem_open` — file-like names, easier semantics. Most modern code uses POSIX or higher-level (Unix sockets, shared mem mapped files).

### 25. Lock-free vs wait-free vs blocking

Blocking: a thread can be paused arbitrarily (mutex). Lock-free: at least one thread always makes progress (CAS loops). Wait-free: every thread makes progress in bounded steps. The trade is complexity vs latency vs throughput.

---

## Filesystems & Storage

### 26. inode vs dentry vs file (in-kernel objects)

- **inode**: the file's metadata (type, perms, owner, size, block pointers). Identifies a file uniquely on a filesystem.
- **dentry**: directory-entry cache — maps a path component name to an inode.
- **file**: an open instance of an inode (an entry in a process's FD table). Multiple `file`s can refer to one inode (multiple opens).

### 27. Hard link vs symlink

Hard link: a directory entry pointing to the same inode. Indistinguishable from the original. Cannot cross filesystems; cannot link directories.
Symlink: a special file containing a path string. Can be dangling, can cross FS, can link directories.

### 28. ext4 journal modes (`data=ordered/writeback/journal`)

- `journal`: data **and** metadata go through the journal first → safest, slowest.
- `ordered` (default): data written to disk before metadata committed → metadata never points at garbage. Reasonable trade.
- `writeback`: only metadata journaled → fastest, but after crash a file may have garbage.

### 29. fsync vs fdatasync

`fsync(fd)` flushes file data + metadata to disk (or to barriers/fua). `fdatasync(fd)` flushes data + only metadata required for retrieval (size). Cheaper. Both honor the underlying device's barrier — which the device may lie about (cheap SSDs).

### 30. Direct IO vs buffered IO

Buffered: goes through page cache. Direct (`O_DIRECT`): bypasses cache, must align IO to device sector. Used by databases that manage their own cache.

### 31. Overlayfs — how does it work?

Stacked filesystem: a read-only `lowerdir` + a read-write `upperdir` + a `workdir`. Reads come from upper if present, else lower. Writes go to upper (file is "copied up" on first write). Whiteouts hide lower files. Backbone of container images (each layer = one lowerdir).

---

## Networking

### 32. The lifetime of a packet (RX path)

NIC receives frame → DMAs into a ring buffer → raises hardware IRQ → kernel runs softirq (NET_RX) which polls ring (NAPI), drains packets into `sk_buff`s → through netfilter PREROUTING → routing decision → FORWARD or LOCAL_IN → through netfilter INPUT → into TCP/UDP layer → into socket receive queue → wakes any task in `recv()`.

### 33. SYN-cookies — what problem do they solve?

Under SYN flood, the SYN queue fills and legit clients are dropped. SYN-cookies encode connection state into the initial SEQ number sent with SYN-ACK; if the client returns a valid ACK, the kernel reconstructs state without ever queuing — at the cost of disabling some TCP options like timestamps/wscale on those connections.

### 34. Nagle vs delayed-ACK — the classic interaction bug

Nagle: hold small writes until ACK or buffer fills. Delayed ACK: receiver waits up to 40 ms before ACKing. Together: small request blocked at sender (Nagle waits for ACK), receiver blocked (delayed ACK waits for more data) → 40 ms stall. Fix with `TCP_NODELAY` for chatty protocols, or batch with `TCP_CORK`.

### 35. Conntrack — why your firewall has memory

Stateful firewalling tracks every flow in a hash table (`/proc/sys/net/netfilter/nf_conntrack_max`). When full, new flows fail. Common at NAT gateways.

### 36. RPS / RSS / RFS — what each does

- **RSS**: NIC hardware fans incoming flows across queues based on a hash of the 5-tuple (each queue → one CPU IRQ).
- **RPS**: software equivalent for NICs lacking RSS — kernel fans softirq processing across CPUs.
- **RFS**: like RPS but steers to the CPU where the *application* last ran with that flow → improves cache locality.

---

## Containers, Namespaces, Cgroups

### 37. Namespaces vs cgroups — clear distinction

**Namespaces** = isolation (what a process can SEE: PIDs, mounts, network, hostname, IPC, users, time, cgroup). 8 namespace types as of recent kernels.
**Cgroups** = accounting and limits (what a process can USE: CPU, memory, IO, PIDs, network bandwidth). v2 unified hierarchy is the modern default.

A container is a process tree wrapped in a set of namespaces + a cgroup with limits + a security policy (seccomp, capabilities, MAC).

### 38. User namespaces — why "rootless" containers work

A user namespace remaps UIDs: a process can be UID 0 inside the namespace but UID 100000 outside. Kernel checks **outside** UID for permission. Lets a non-root host user run a "root" container safely. Some operations still require host root (e.g. mount certain FS types) — there are still restrictions.

### 39. cgroup v1 vs v2 — what changed?

v1: separate hierarchies per controller (cpu, memory, io independent). Awkward, controllers can't coordinate.
v2: single unified hierarchy; one tree, controllers attached per node. Better memory↔io coordination, **PSI** (Pressure Stall Information), io.cost weighted IO. Modern systems (systemd, k8s) standardize on v2.

### 40. Capabilities — name 5 you actually care about

- `CAP_NET_BIND_SERVICE` — bind below port 1024 (replaces setuid for nginx/etc).
- `CAP_NET_ADMIN` — configure network (containers usually drop).
- `CAP_SYS_ADMIN` — the "kitchen sink" capability; almost-root. Avoid granting.
- `CAP_DAC_OVERRIDE` — bypass file permission checks.
- `CAP_SYS_PTRACE` — debug other processes; required for `gdb -p` across users.

The full list is `man 7 capabilities`. Modern best practice: drop ALL, add back the minimal set. Capabilities are a more granular replacement for setuid root.

---

## Bonus pattern questions

### A. "Walk me through what happens when I run `curl https://example.com`"

Shell: parses, forks, execs `curl`. curl: parses URL → calls `getaddrinfo` (NSS → DNS → cache or `dig`) → opens TCP socket → connect (3-way handshake) → TLS handshake (ClientHello, cert chain validation, key exchange, finished) → writes HTTP request → reads response → closes TLS+TCP → exits. Each step has potential failure modes you should be ready to enumerate.

### B. "Why is `strace` slow?"

`strace` uses `ptrace(2)` — every syscall causes two extra context switches (entry + exit) plus copying syscall args to userspace. Easily 10-100x slowdown. Modern alternative: **bpftrace** / **perf trace** uses tracepoints/eBPF — much lower overhead, suitable on production.

### C. "What's the difference between systemd and init?"

SysV init runs `/etc/rc.d/rc<runlevel>.d/*` scripts serially. systemd is a parallel dependency-driven service manager + supervisor + logger + timer + network + mount manager. Same PID 1, vastly different model. Critically, systemd integrates cgroups (each service in its own cgroup), structured logging (journal), and socket activation.

---

## How to use these questions

Pick 5 you can't answer cleanly. Find the LWN article / kernel doc / Brendan Gregg blog. Read it. Re-explain to yourself in plain English. Do this 8x and you've moved a noticeable amount of senior-interview readiness.

The deepest signal you can give in an interview isn't trivia recall — it's saying:

> "I don't remember the exact flag, but the model is X, the tradeoff is Y, and I'd verify with Z."
