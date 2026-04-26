# Troubleshooting — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway shell with the deep-dive trio + helpers
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y strace lsof procps psmisc curl tcpdump ncdu sysstat >/dev/null
```

## Core commands

```bash
# Logs — current boot, errors and worse
journalctl -p err -b
```

```bash
# Logs — narrow by unit + window
journalctl -u nginx --since '15 min ago'
```

```bash
# Kernel ring buffer with human timestamps + severity filter
dmesg -T --level=err,warn | tail
```

```bash
# Follow new kernel messages
dmesg -w
```

```bash
# Load average + uptime
uptime
```

```bash
# Memory + swap, human readable
free -h
```

```bash
# Combined CPU/mem/IO/swap snapshot every 1s, 5 samples
vmstat 1 5
```

```bash
# Per-CPU usage (sysstat)
mpstat -P ALL 1
```

```bash
# Per-device IO with extended stats
iostat -xz 1
```

```bash
# Per-process CPU/IO
pidstat 1
```

```bash
# All FDs of a PID (files, sockets, pipes)
lsof -p <pid>
```

```bash
# Who is bound to a port
lsof -i :80
```

```bash
# Who has a specific file open
lsof /var/log/syslog
```

```bash
# Leaked deleted-but-open files (the disk-eater hunt)
lsof | grep deleted
```

```bash
# Attach strace to a running PID
strace -p <pid>
```

```bash
# Follow forks, filter syscalls
strace -f -e trace=openat,connect ./prog
```

```bash
# Syscall summary: count, errors, time per syscall
strace -c ./prog
```

```bash
# Listening sockets
ss -tulpn
```

```bash
# Count established connections
ss -tan state established | wc -l
```

```bash
# 20 packets on port 443 (any interface)
tcpdump -i any -nn 'port 443' -c 20
```

```bash
# Capture to pcap for Wireshark
tcpdump -i eth0 -w /tmp/cap.pcap
```

```bash
# Combined ping+trace
mtr -n example.com
```

```bash
# Quick port-reachability check
nc -zv host 443
```

```bash
# Who has this file/port open
fuser -v /var/log/syslog
fuser -v 8080/tcp
```

## Inspection / verification

```bash
# Where in the kernel is a process stuck
cat /proc/<pid>/stack
cat /proc/<pid>/wchan; echo
```

```bash
# Process state, threads, capabilities
cat /proc/<pid>/status
```

```bash
# Confirm a process consumes no CPU (truly hung vs busy-loop)
top -b -n 1 -p <pid> | tail -3
```

```bash
# Find OOM kills + hardware faults after a mysterious crash
journalctl -k | grep -iE 'oom|killed|error'
```

## Cleanup

```bash
# Kill anyone holding a TCP port (careful!)
fuser -k 8080/tcp
```

```bash
# Stop a tcpdump background job
kill %1 2>/dev/null
```

## One-liners worth memorising

```bash
# Brendan Gregg's 60-second triage
uptime; dmesg -T | tail; vmstat 1 5; mpstat -P ALL 1 1; pidstat 1 1; iostat -xz 1 1; free -m; sar -n DEV 1 1; sar -n TCP,ETCP 1 1
```

```bash
# Top disk-eaters under a directory
du -h --max-depth=1 /var 2>/dev/null | sort -rh | head
```

```bash
# Trace what curl asks the kernel for (DNS + connect)
strace -e trace=network,openat -f curl -s http://example.com -o /dev/null 2>&1 | grep -E 'connect|openat.*resolv'
```

```bash
# Find deleted files still consuming disk
lsof +L1
```

```bash
# Tail a log that gets rotated (capital F reopens)
tail -F /var/log/app.log
```

```bash
# Who is on this port + kill the owner
ss -tulpn 'sport = :9000' && fuser -k 9000/tcp
```
