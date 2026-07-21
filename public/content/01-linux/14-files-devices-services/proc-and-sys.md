# /proc and /sys — The Kernel as a Filesystem

> If a question begins with "what is the kernel currently doing about...", the answer almost always lives under `/proc` or `/sys`.

## Why this matters

The two pseudo-filesystems `procfs` and `sysfs` are how Linux exposes its **internal state** to userspace. You don't need a debugger or a kernel module to inspect process memory layout, CPU topology, slab allocator stats, NUMA balancing, scheduler classes, or per-device queue depth — you `cat` a file. Every monitoring tool you know (`top`, `htop`, `iostat`, `ps`, `free`, `uptime`, `vmstat`) is just a friendly front-end to these files. Master them and you can debug systems where you don't have those tools installed.

## How procfs and sysfs differ

```mermaid
flowchart LR
    subgraph procfs["/proc — legacy + per-process"]
        P1["PID dirs<br/>per-process state"]
        P2["Global info<br/>cpuinfo, meminfo, loadavg"]
        P3["/proc/sys<br/>writable kernel tunables"]
    end
    subgraph sysfs["/sys — modern device model"]
        S1[/sys/class — by function]
        S2[/sys/block — block devs]
        S3[/sys/devices — physical tree]
        S4[/sys/fs/cgroup — cgroup v2]
        S5[/sys/module — loaded modules]
    end
    KOBJ["kobject layer<br/>+ ksets"] --> sysfs
    TASK[task_struct, mm_struct, ...] --> procfs
```

| | procfs | sysfs |
|--|--|--|
| **Mounted at** | /proc | /sys |
| **Mount type** | proc | sysfs |
| **Created** | 1993 (Linux 0.99) | 2003 (Linux 2.6) |
| **Discipline** | mixed; many values per file | one value per file |
| **Writable knobs** | `/proc/sys/*` | per-attribute |
| **Backed by** | task_struct + global vars | kobject hierarchy |

## Per-process: `/proc/<pid>/`

The most useful directory in the entire kernel. One subdirectory per running task. Many entries are also available as `/proc/<pid>/task/<tid>/` for individual threads.

| Path | What it is |
|------|-----------|
| `cmdline` | NUL-separated argv vector |
| `comm` | short command name (≤ 15 chars) |
| `status` | human-readable state, UIDs, capabilities, signal masks |
| `stat` | machine-readable state (parsed by `ps`, `top`) |
| `maps` | virtual memory map (every mmap'd region) |
| `smaps` | as `maps` but with per-region RSS, PSS, swap |
| `fd/` | symlinks to every open file descriptor |
| `fdinfo/` | flags, position, mnt_id per fd |
| `limits` | rlimits (nofile, nproc, stack, etc.) |
| `environ` | NUL-separated environment at exec time |
| `cwd` | symlink to current working directory |
| `exe` | symlink to the executable (survives `rm`) |
| `root` | symlink to the process's `/` (chroot/pivot_root) |
| `ns/` | namespace IDs — compare two PIDs to see if they share a namespace |
| `cgroup` | which cgroups the process belongs to |
| `oom_score` / `oom_score_adj` | OOM killer ranking |
| `wchan` | kernel function the task is sleeping in |
| `stack` | kernel stack trace (requires CONFIG_STACKTRACE) |

```bash
# What command is PID 1234 running, and what env did it inherit?
tr '\0' ' ' < /proc/1234/cmdline; echo
tr '\0' '\n' < /proc/1234/environ | sort

# Every file descriptor — including pipes and sockets
ls -l /proc/1234/fd
# lrwx------ 1 root root 64 Apr 26 10:11 0 -> /dev/null
# lrwx------ 1 root root 64 Apr 26 10:11 1 -> 'pipe:[83451]'
# lr-x------ 1 root root 64 Apr 26 10:11 3 -> /etc/nginx/nginx.conf

# Memory map — find which library a crash address is in
cat /proc/1234/maps | head
# 55a7b2c00000-55a7b2c2e000 r--p 00000000 fd:01 1180 /usr/sbin/nginx
# 55a7b2c2e000-55a7b2cb0000 r-xp 0002e000 fd:01 1180 /usr/sbin/nginx

# Real RSS per region (PSS = proportional set size, what shared libs really cost you)
sudo grep -E '^(VmRSS|RssAnon|RssFile|RssShmem)' /proc/1234/status
```

## System-wide files in `/proc`

| File | Content |
|------|---------|
| `cpuinfo` | one block per logical CPU: model, MHz, flags |
| `meminfo` | MemTotal, MemFree, Available, Buffers, Cached, Slab, ... |
| `loadavg` | 1/5/15-min load, runnable/total tasks, last PID |
| `swaps` | active swap devices and usage |
| `mounts` | every mount in the current mount namespace |
| `slabinfo` | slab allocator caches (where most kernel memory lives) |
| `interrupts` | IRQ count per CPU per device — find a noisy NIC |
| `softirqs` | softirq counts (NET_RX, RCU, TIMER, ...) |
| `net/dev` | per-interface packet/byte/error counters |
| `net/tcp` / `net/tcp6` | every TCP socket as text |
| `vmstat` | counters for paging, allocations, NUMA |
| `diskstats` | per-block-device IO counters |
| `partitions` | major:minor → name table |
| `modules` | loaded modules (same as `lsmod` parses) |
| `kallsyms` | every kernel symbol (root-only) |

```bash
# What kind of CPU am I on?
grep -m1 'model name' /proc/cpuinfo
# model name : Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz

# Available memory the way the kernel computes it (NOT MemFree!)
grep MemAvailable /proc/meminfo
# MemAvailable:   12483440 kB

# Which IRQs are landing on which CPU?
head -1 /proc/interrupts
awk 'NR>1 && /eth0/' /proc/interrupts
```

## sysctl — tunable kernel knobs via `/proc/sys`

Everything under `/proc/sys/` is writable (root). The `sysctl` command is just a wrapper that translates dots to slashes.

```bash
# These are equivalent:
sysctl net.ipv4.ip_forward
cat /proc/sys/net/ipv4/ip_forward

sysctl -w vm.swappiness=10
echo 10 > /proc/sys/vm/swappiness

# Persist across reboots:
cat > /etc/sysctl.d/99-tuning.conf <<'EOF'
vm.swappiness = 10
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse = 1
fs.inotify.max_user_watches = 524288
EOF
sysctl --system          # reload all *.conf in /etc/sysctl.d/, /run/, /usr/lib/
```

## sysfs anatomy

```mermaid
flowchart TD
    sys[/sys] --> class[class/]
    sys --> block[block/]
    sys --> dev[devices/]
    sys --> fs[fs/]
    sys --> module[module/]
    class --> net[net/]
    class --> tty[tty/]
    class --> bdi[bdi/]
    net --> eth0[eth0/]
    eth0 --> mtu[mtu]
    eth0 --> oper[operstate]
    eth0 --> stats[statistics/]
    block --> sda[sda/]
    sda --> queue[queue/]
    queue --> sched[scheduler]
    queue --> nrreq[nr_requests]
    queue --> rotat[rotational]
    fs --> cg[cgroup/]
```

| Path | Use case |
|------|----------|
| `/sys/class/net/<iface>/` | NIC state — link up/down, MAC, MTU, statistics |
| `/sys/class/thermal/` | thermal zones, fan speeds |
| `/sys/class/power_supply/BAT0/` | laptop battery state |
| `/sys/block/<dev>/queue/` | IO scheduler, queue depth, rotational flag |
| `/sys/block/<dev>/size` | size in 512-byte sectors |
| `/sys/devices/system/cpu/cpu*/online` | hot-unplug a CPU by writing 0 |
| `/sys/devices/system/cpu/cpu*/cpufreq/` | per-CPU frequency governor |
| `/sys/fs/cgroup/` | cgroup v2 hierarchy (memory.max, cpu.weight, io.stat) |
| `/sys/module/<name>/parameters/` | currently effective module parameters |

```bash
# Is eth0 link up?
cat /sys/class/net/eth0/operstate
# up

# IO scheduler currently active on nvme0n1
cat /sys/block/nvme0n1/queue/scheduler
# [none] mq-deadline kyber bfq

# Switch to mq-deadline (active option in [brackets])
echo mq-deadline > /sys/block/nvme0n1/queue/scheduler

# Memory limit on a systemd service's cgroup
cat /sys/fs/cgroup/system.slice/nginx.service/memory.max
# max     ← unlimited
```

## Lab walkthrough — finding what a process is really doing

```bash
# Pick the heaviest process by RSS
$ ps -eo pid,rss,comm --sort=-rss | head -5
    PID    RSS COMMAND
   1487 412300 firefox
   1490 198024 Web Content
   1234  82440 nginx
    902  41200 systemd-journal
    883  18044 systemd

# Drill into nginx (PID 1234)
$ ls /proc/1234/
attr  cmdline  cwd  environ  exe  fd  fdinfo  io  limits  maps  mounts
ns  oom_score  smaps  stat  status  task  wchan  ...

# What was it told to do?
$ tr '\0' ' ' < /proc/1234/cmdline; echo
nginx: master process /usr/sbin/nginx -g daemon on; master_process on;

# What files does it have open?
$ sudo ls -l /proc/1234/fd | awk '{print $9, $10, $11}'
0 -> /dev/null
1 -> /dev/null
2 -> /dev/null
3 -> /var/log/nginx/access.log
4 -> /var/log/nginx/error.log
6 -> 'socket:[83451]'
7 -> 'socket:[83452]'

# Translate socket inode → port
$ sudo ss -tlnp | grep 83451
LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1234,fd=6))

# How much memory is really nginx's vs shared with libc?
$ sudo awk '/^Pss:/{sum+=$2} END{print sum" kB"}' /proc/1234/smaps
38214 kB

# What rlimits does it have?
$ cat /proc/1234/limits | head
Limit                     Soft Limit  Hard Limit  Units
Max open files            65535       65535       files
Max processes             unlimited   unlimited   processes
Max stack size            8388608     unlimited   bytes
```

## Hot reads for SREs

```bash
# Top 10 contributors to slab cache (kernel memory)
sudo awk 'NR>2 {print $1, $3*$4/1024" KB"}' /proc/slabinfo | sort -k2 -n -r | head

# Which CPUs are taking which IRQs (find an unbalanced NIC)
column -t /proc/interrupts | less -S

# Dirty pages waiting to be flushed
grep -E 'Dirty|Writeback' /proc/meminfo

# How many file descriptors are in use system-wide?
cat /proc/sys/fs/file-nr   # allocated  free  max
```

> **Gotchas**
> - `/proc/<pid>/maps` and `/proc/<pid>/fd` require either ownership or `CAP_SYS_PTRACE` (root).
> - Reading `/proc/kcore` is enormous (size of physical RAM) and pointless without `gdb`.
> - Many `/sys` files require **exact** content — including a trailing newline — and will reject otherwise. Use `printf` not `echo -n` when in doubt.
> - `/proc/<pid>/status`'s `VmRSS` is the *resident* size; it double-counts shared libs across processes. Use `Pss` from `smaps_rollup` for honest accounting.

> **20-year tips**
> - When a node is "slow", `cat /proc/pressure/{cpu,memory,io}` first. PSI tells you which resource is saturated in seconds.
> - `lsof` on a busy box is slow. `ls -l /proc/*/fd 2>/dev/null | grep <inode>` is faster when you know the inode.
> - `/proc/<pid>/oom_score_adj = -1000` makes a process unkillable by OOM. Use it for monitoring agents — never for the workload you're trying to monitor.
> - `cat /proc/self/mountinfo` is far richer than `/proc/mounts` — it has propagation flags, mount IDs, and supersources.
> - `cat /proc/<pid>/wchan` gives a one-word answer to "why is this process stuck?" Often it's `futex_wait` (lock contention) or `io_schedule` (waiting on disk).

> **Common interview questions**
> 1. **Q:** How would you find which process opened a deleted file that's still consuming disk?
>    **A:** `lsof | grep deleted` — backed by reading `/proc/*/fd/*` symlinks and noticing they point at "(deleted)".
> 2. **Q:** What's the difference between `/proc/meminfo`'s `MemFree` and `MemAvailable`?
>    **A:** `MemFree` is truly idle; `MemAvailable` adds reclaimable cache and slab — it's what apps can realistically allocate without swapping.
> 3. **Q:** How do you persist a sysctl change?
>    **A:** Drop a file in `/etc/sysctl.d/` and run `sysctl --system`. Editing `/etc/sysctl.conf` works but is the legacy path.
> 4. **Q:** Why is one value per file the rule in sysfs?
>    **A:** Atomicity and parseability — a single `read()` returns one consistent value. Multi-value files (procfs-style) require parsing and risk torn reads.
> 5. **Q:** What does `/proc/<pid>/exe` point to after `rm /usr/bin/foo`?
>    **A:** Still the original inode — the kernel keeps the i-link until the process exits. This is how you recover deleted binaries: `cp /proc/<pid>/exe /tmp/foo`.
> 6. **Q:** How do containers see different `/proc/cpuinfo`?
>    **A:** They don't, by default — `/proc` is shared. Tools like LXCFS overlay a fake `/proc/cpuinfo` that respects the cgroup's CPU set.
> 7. **Q:** Where do you change the default IO scheduler?
>    **A:** Per-device runtime: `/sys/block/<dev>/queue/scheduler`. Persistent: a udev rule or kernel cmdline `elevator=` (deprecated; use udev).

## Sources

- `man 5 proc` — comprehensive procfs reference
- `man 5 sysfs`
- Linux kernel `Documentation/filesystems/proc.rst`
- Linux kernel `Documentation/admin-guide/sysctl/`
- Linux kernel `Documentation/ABI/stable/sysfs-*`
- Greg Kroah-Hartman, "udev — A Userspace Implementation of devfs"
