# Linux · commands quick-pick

> One-liners ordered by "what do I reach for when I'm paged at 03:00." Three panes: **triage** (what is wrong?), **diagnose** (why?), **fix** (unblock it). Copy, don't type — muscle memory comes from repetition, but the pager isn't the time to practise spelling.

---

## Pane 1 — Triage (first 60 seconds)

```bash
# Who am I, where am I, what am I allowed to do?
id; hostname -f; uptime

# Five-window system health
uptime                                  # load average: is CPU queue growing?
free -h                                 # RAM + swap usage
df -hT                                  # filesystem capacity + type
df -i                                   # inode pressure (the other "disk full")
ss -s                                   # socket summary: TCP counts, TIME-WAIT

# Top offenders, right now
top -o %CPU -b -n 1 | head -20          # CPU leaders (batch, not interactive)
top -o %MEM -b -n 1 | head -20          # memory leaders
ps -eo pid,ppid,%cpu,%mem,stat,cmd --sort=-%cpu | head

# What's listening, who owns it?
ss -tulpn                               # replaces netstat, 100x faster
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null # alt view with opened-by pid

# Recent auth / sudo / cron events
journalctl --since "15 min ago" -p warning --no-pager | tail -30
last -n 10                              # successful logins
lastb -n 10 2>/dev/null                 # failed logins (root only)
```

---

## Pane 2 — Diagnose (the next 5 minutes)

### Filesystem & inodes

```bash
# Find what ate the inodes / space
find / -xdev -type f 2>/dev/null | awk -F/ '{print $2"/"$3}' | sort | uniq -c | sort -n | tail
du -xhd 1 /var 2>/dev/null | sort -h | tail         # top dirs under /var
find / -xdev -size +500M 2>/dev/null -exec ls -lh {} \;   # oversized files

# Is a file deleted but still held open (disk looks full but du is low)?
lsof -nP +L1 2>/dev/null | head

# Ground truth of mounts (not /etc/fstab)
findmnt -A
cat /proc/mounts | column -t | head

# Inode + link detective work
ls -li suspect.file                    # inode + link count
find / -xdev -inum 24601 2>/dev/null    # every name pointing at one inode
stat suspect.file
```

### Processes & signals

```bash
# Live process tree with threads
ps -eLf --forest | less
pstree -p $(pgrep -o nginx)

# Attach syscall counter for 5s, then detach
strace -c -p $(pgrep -o myapp) -f & sleep 5; kill %1

# Detect zombies
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'

# Who is the PID-1 of this container?
ps -eo pid,comm | awk '$1==1'           # should be your app or tini, not bash

# Memory pressure per process
ps -eo pid,rss,vsz,cmd --sort=-rss | head
cat /proc/$PID/status | grep -E 'VmRSS|VmSize|Threads|State'
```

### Networking

```bash
# Is it a listener bind or a firewall issue?
ss -tulpn | grep :5432
nft list ruleset 2>/dev/null || iptables -L -n -v

# Is DNS or the resolver itself broken?
getent ahosts api.example.com           # uses nsswitch + /etc/hosts + DNS
dig +short api.example.com @1.1.1.1     # bypass resolver

# What path would a packet take?
ip route get 10.0.0.5
ip -br a; ip -br l

# Capture just enough packets to see the failure
tcpdump -i any -n -c 50 host api.example.com and port 443

# Active connections, sorted by state
ss -tn state established '( dport = :443 or sport = :443 )'
ss -s                                   # TCP summary (TIME-WAIT, etc.)
```

### Disk & I/O

```bash
# Saturation + latency per device (sysstat)
iostat -xz 1 5                          # %util, await, r/w kB

# Per-process I/O
pidstat -d 1 5                          # requires SYS_PTRACE inside containers
iotop -oP 2>/dev/null                   # interactive

# Block device topology
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
blkid
findmnt -A

# LVM snapshot
pvs; vgs; lvs
```

### systemd & journald

```bash
# Unit status + last 30 logs
systemctl status myapp.service --no-pager -l
journalctl -u myapp.service -n 50 --no-pager
journalctl -u myapp.service -f --since "5 min ago"     # stream

# Who failed since last boot?
systemctl --failed
systemctl list-units --state=failed --no-pager

# Timers
systemctl list-timers --all --no-pager

# Kernel messages since boot (ring buffer)
dmesg -T | tail -50
journalctl -k --since "10 min ago" --no-pager
```

### Users, PAM, sudoers

```bash
# Identity
id alice
getent passwd alice
getent group sudo

# Was this user locked out? Why?
passwd -S alice                         # L/P/NP = locked/passworded/no pwd
faillock --user alice 2>/dev/null || pam_tally2 --user alice

# Sudoers integrity
visudo -c                               # validates all drop-ins
sudo -l -U alice                        # what alice is allowed to run

# Recent escalation
journalctl _COMM=sudo --since "1 hour ago" --no-pager | head
grep -E 'sudo|session' /var/log/auth.log 2>/dev/null | tail
```

### Triage deep dive — `/proc` walkthrough

```bash
# Everything a process knows about itself
PID=$(pgrep -o myapp)
ls /proc/$PID/
cat /proc/$PID/status | head -20        # threads, rss, uid, signals
cat /proc/$PID/limits                   # ulimits as this process sees them
cat /proc/$PID/io                       # bytes read/written to disk
cat /proc/$PID/stack 2>/dev/null        # kernel stack — where is it stuck?
ls -l /proc/$PID/fd | head              # open file descriptors
ls -l /proc/$PID/cwd /proc/$PID/exe     # cwd and binary path
cat /proc/$PID/cgroup                   # cgroup membership (container scope)

# System-wide kernel state
cat /proc/loadavg
cat /proc/meminfo | head -20
cat /proc/net/sockstat
```

---

## Pane 3 — Fix (make the bleeding stop)

### Process & signal control

```bash
# Graceful shutdown first — always
kill -TERM $PID                         # == kill -15 == default
kill -HUP  $PID                         # "reload config" convention
sleep 10
kill -0    $PID && kill -KILL $PID      # only if TERM ignored

# By name (safer than killall)
pkill -TERM -f 'myapp --config=/etc/myapp.yml'

# Reap zombies — only by fixing or restarting the parent
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/ {print $2}' | sort -u
# → restart those PPIDs; kernel reaps orphans on PID 1
```

### File & permission repair

```bash
# Ownership + mode reset
chown -R app:app /opt/app
find /opt/app -type d -exec chmod 0755 {} \;
find /opt/app -type f -exec chmod 0644 {} \;
find /opt/app/bin -type f -exec chmod 0755 {} \;

# Scoped ACL instead of chmod 777
setfacl -m u:deploy:rx /opt/app
setfacl -m d:u:deploy:rx /opt/app       # default ACL for new files

# Strip the sticky / setuid you didn't mean
chmod u-s /usr/local/bin/oops

# Recover space from deleted-but-open files
lsof -nP +L1 | awk '/REG/ {print $2}' | sort -u | xargs -r -n1 kill -HUP
# or: >/proc/$PID/fd/$FD   # truncate the open fd in place
```

### Networking unblock

```bash
# Bring an interface back
ip link set eth0 up
ip addr add 10.0.0.5/24 dev eth0
ip route add default via 10.0.0.1

# Open a port with nftables
nft add rule inet filter input tcp dport 5432 accept
# or legacy iptables
iptables -I INPUT -p tcp --dport 5432 -j ACCEPT

# Quick temporary allow-list (single IP, 1 minute, then auto-revert)
nft add rule inet filter input ip saddr 1.2.3.4 accept; \
  ( sleep 60 && nft flush ruleset ) &

# Flush the resolver cache (systemd-resolved)
resolvectl flush-caches; resolvectl statistics
```

### Disk & I/O rescue

```bash
# Truncate a runaway log without restarting the writer
truncate -s 0 /var/log/app.log
# or keep tailing: > /var/log/app.log

# Emergency free: rotate + compress + delete old
logrotate -f /etc/logrotate.d/app
journalctl --vacuum-size=500M
journalctl --vacuum-time=2d
apt-get clean; rm -rf /var/cache/apt/archives/*.deb

# LVM live-grow
lvextend -r -L +10G /dev/vg0/data       # -r resizes fs too (ext4/xfs)

# Remount read-only when the FS is misbehaving
mount -o remount,ro /data               # last resort before umount
```

### systemd — restart, reload, override

```bash
# Cold start / restart
systemctl daemon-reload                 # after editing unit files
systemctl restart myapp.service
systemctl reload myapp.service          # if ExecReload= is defined

# Mask to prevent any start (stronger than disable)
systemctl mask bad.service

# Drop-in override without editing vendor unit
systemctl edit myapp.service            # opens $EDITOR on override.conf
# or manually:
mkdir -p /etc/systemd/system/myapp.service.d
cat > /etc/systemd/system/myapp.service.d/override.conf <<'EOF'
[Service]
MemoryMax=512M
Environment=LOG_LEVEL=debug
EOF
systemctl daemon-reload && systemctl restart myapp.service

# Kick a timer to run right now (test mode)
systemctl start myapp.service           # the service its timer triggers
```

### Users / sudo hotfix

```bash
# Lock an account instantly
passwd -l alice
usermod --expiredate 1 alice            # harder: expires today

# Force password change on next login
chage -d 0 alice

# Emergency revoke sudo
rm /etc/sudoers.d/alice
visudo -c

# Clear faillock after a lockout
faillock --user alice --reset
```

---

## Pane 4 — Forensics (after the incident)

```bash
# Timeline of events (journald, systemd)
journalctl --since "2026-04-27 08:00" --until "2026-04-27 09:00" --no-pager

# Who ran what with sudo
journalctl _COMM=sudo --since "2 hours ago" --no-pager

# Which files were touched in the last 30 minutes?
find / -xdev -type f -mmin -30 2>/dev/null | head

# OOM kills (kernel log)
dmesg -T | grep -iE 'killed process|out of memory'
journalctl -k --since "1 hour ago" | grep -iE 'oom|killed'

# Login records
last -F | head
lastb -F | head

# Package changes (Debian/Ubuntu)
grep -E "install |upgrade " /var/log/dpkg.log | tail
# RHEL/Fedora
rpm -qa --last | head
```

---

## Bash strict mode — copy into every script

```bash
#!/usr/bin/env bash
set -Eeuo pipefail                      # errors, unset vars, pipe failures
IFS=$'\n\t'                             # safer word-splitting
trap 'rc=$?; echo "exit $rc at line $LINENO" >&2' ERR
trap 'rm -rf "${TMP:-}"' EXIT

TMP="$(mktemp -d)"                      # auto-cleaned by the EXIT trap
# ... your code ...
```

---

## Container-friendly install bundle

```bash
# Inside Ubuntu/Debian container: install everything above at once
apt-get update && apt-get install -y --no-install-recommends \
  iproute2 iputils-ping dnsutils procps psmisc lsof strace tcpdump \
  net-tools jq tree htop sudo cron sysstat ltrace file less \
  linux-tools-common linux-tools-generic
```

---

## The 10-command survival kit

If you only memorise ten, make it these:

| # | Command | What it answers |
|---|---------|-----------------|
| 1 | `journalctl -u <unit> -f --since "5 min ago"` | "What is this service saying right now?" |
| 2 | `systemctl status <unit> --no-pager -l` | "Is the service alive? Last lines of log?" |
| 3 | `ss -tulpn` | "Who is listening, on what port, as which process?" |
| 4 | `ps -eo pid,ppid,%cpu,%mem,stat,cmd --sort=-%cpu \| head` | "Who's hot right now?" |
| 5 | `strace -c -p <PID> -f` | "What syscalls is this process hammering?" |
| 6 | `iostat -xz 1 5` | "Is the disk the bottleneck?" |
| 7 | `df -hT; df -i` | "Out of bytes or out of inodes?" |
| 8 | `dig +short NAME; getent ahosts NAME` | "Is DNS lying to me?" |
| 9 | `lsof -nP -p <PID>` | "Every file and socket this process has open." |
| 10 | `journalctl -k --since "10 min ago"` | "What did the kernel say?" |

> Print this page. Tape it next to your monitor. The pager does not wait for you to google.
