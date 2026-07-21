# 📋 Linux DevOps Cheat Sheet

> One-page reference. Print it, pin it, paste it.

## Filesystem

```bash
pwd                        # current dir
ls -lah                    # detailed listing
cd -                       # last dir
tree -L 2                  # 2 levels deep
stat file                  # inode + times
file binary                # detect type
df -hT                     # disk usage by fs
du -sh dir                 # dir size
findmnt                    # mount tree
ln    src dst              # hard link
ln -s src dst              # symlink
readlink -f path           # resolve symlinks
find / -name '*.log' -mtime -1
find . -type f -size +100M
```

## Users & Permissions

```bash
id ; whoami ; groups
useradd -m -s /bin/bash alice
passwd alice
usermod -aG sudo alice
userdel -r alice
chmod 750 file             # rwxr-x---
chmod u+x,g-w,o= file
chown user:group file
umask 0022
sudo -l                    # what can I sudo?
visudo -f /etc/sudoers.d/x
# Special bits
chmod u+s   file           # setuid (4000)
chmod g+s   dir            # setgid (2000)
chmod +t    dir            # sticky (1000)
```

## Processes

```bash
ps aux                     # all processes
ps -ef
pstree -p
top  /  htop
kill PID                   # SIGTERM
kill -9 PID                # SIGKILL
kill -HUP PID              # reload
killall nginx
pkill -f 'python myapp'
nice -n 10 ./job
renice -n 5 -p PID
nohup ./run >out 2>&1 &
disown
jobs ; fg %1 ; bg %1
cat /proc/PID/status
ls /proc/PID/fd
```

## Networking

```bash
ip -br -c addr
ip route ; ip route get 1.1.1.1
ss -tulpn                  # listening
ss -tan state established
ping -c 4 host
traceroute -n host
mtr host
dig +short example.com
dig @8.8.8.8 example.com MX
dig +trace example.com
getent hosts example.com
curl -I https://x          # HEAD
curl -v https://x          # verbose
curl -s -o /dev/null -w '%{http_code}\n' URL
nc -zv host 443
tcpdump -i any -nn 'port 443' -c 10
iptables -L -n -v
```

## Bash scripting

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VAR="${1:?usage: $0 <arg>}"
trap 'rm -rf "$TMP"' EXIT
TMP=$(mktemp -d)

# Conditionals
[[ -f file ]] && echo exists
[[ "$x" == a* ]] && echo "starts with a"
case "$1" in start) ;; stop) ;; *) ;; esac

# Loops
for i in {1..5}; do echo $i; done
for f in /etc/*.conf; do echo "$f"; done
while read -r line; do echo "$line"; done < file

# Functions
fn() { local x="${1:?}"; echo "$x"; }

# Tests
# -e exists  -f file  -d dir  -L symlink  -r readable
# -s nonempty file  -x exec  -z empty str  -n nonempty str

shellcheck script.sh       # always lint
```

## systemd

```bash
systemctl status nginx
systemctl start|stop|restart|reload nginx
systemctl enable --now nginx
systemctl daemon-reload    # after editing units
systemctl list-units --type=service
systemctl list-timers --all
systemctl edit nginx       # drop-in override
systemctl cat nginx
journalctl -u nginx -f
journalctl -u nginx --since '1 hour ago'
journalctl -p err -b
journalctl --vacuum-time=7d
systemd-analyze blame
```

## Package management

```bash
# Debian / Ubuntu
apt update && apt install -y pkg
apt remove -y pkg ; apt purge -y pkg
apt search pkg ; apt show pkg
dpkg -l | grep pkg
dpkg -S /path              # which pkg owns
dpkg -L pkg                # files in pkg

# RHEL / Fedora
dnf install -y pkg ; dnf remove -y pkg
dnf provides /usr/bin/x
rpm -qa ; rpm -ql pkg ; rpm -qf /path

# macOS / Linux
brew install pkg ; brew uninstall pkg
brew list ; brew info pkg
```

## Text processing

```bash
grep -i 'pat' file
grep -rn 'pat' src/
grep -E 'a|b' file ; grep -P '\d+' file
grep -A2 -B1 'pat' file

cut -d: -f1 /etc/passwd
cut -c1-10 file

sort file ; sort -n ; sort -k2 -t,
sort -u                    # unique
uniq -c                    # count consecutive
sort | uniq -c | sort -rn  # frequency

sed 's/foo/bar/g' file
sed -i 's/foo/bar/g' file  # in-place
sed -n '5,10p' file
sed '/^#/d' file

awk '{print $1}'
awk -F: '{print $1,$7}' /etc/passwd
awk '$3>1000' file
awk '{s+=$1} END {print s}'

tr 'a-z' 'A-Z' < f
wc -l file
xargs -n1 -I{} echo {}
find . -name '*.tmp' -print0 | xargs -0 rm

jq .
jq '.items[] | .name' f.json
jq -r '.[] | "\(.id),\(.name)"'
```

## Storage

```bash
lsblk -f
blkid
df -hT ; df -i             # bytes vs inodes
du -h --max-depth=1 / | sort -rh | head
mount /dev/sdb1 /mnt/data
umount /mnt/data
findmnt /home
mount -a                   # apply fstab

mkfs.ext4 /dev/sdb1
mkfs.xfs  /dev/sdb1
resize2fs /dev/mapper/lv
xfs_growfs /mnt/data

# LVM
pvcreate /dev/sdb1
vgcreate vg /dev/sdb1
lvcreate -L 10G -n lv vg
lvextend -L +5G /dev/vg/lv && resize2fs /dev/vg/lv
pvs ; vgs ; lvs

# Loopback (labs)
dd if=/dev/zero of=/tmp/d.img bs=1M count=100
losetup -fP /tmp/d.img ; losetup -a ; losetup -d /dev/loop0
```

## Troubleshooting

```bash
uptime ; free -h ; vmstat 1 5
mpstat -P ALL 1
iostat -xz 1
pidstat 1
sar -u 1 5
dmesg -T --level=err,warn | tail
dmesg -w

lsof -p PID
lsof -i :80
lsof | grep deleted        # leaked open files
fuser -v /path
fuser -k 8080/tcp          # kill port holders

strace -p PID
strace -f -e trace=openat,connect ./prog
strace -c ./prog           # summary

cat /proc/PID/status
cat /proc/PID/stack
cat /proc/PID/wchan; echo

ncdu /                     # interactive du
```

## Signals (most-used)

| # | Name | Use |
|---|------|-----|
| 1 | HUP | reload config |
| 2 | INT | Ctrl-C |
| 9 | KILL | uncatchable, last resort |
| 15 | TERM | polite shutdown (default `kill`) |
| 17 | CHLD | child changed state |
| 18 | CONT | continue stopped |
| 19 | STOP | uncatchable pause |
| 20 | TSTP | Ctrl-Z |

## Exit codes (conventions)

| Code | Meaning |
|------|---------|
| 0 | success |
| 1 | generic error |
| 2 | misuse of shell builtin |
| 126 | not executable |
| 127 | command not found |
| 128+N | killed by signal N (e.g. 137 = 128+9 = SIGKILL) |
| 130 | Ctrl-C (128+2) |

## File test operators (`[[ ... ]]`)

| Op | True if |
|----|---------|
| `-e f` | exists |
| `-f f` | regular file |
| `-d f` | directory |
| `-L f` | symlink |
| `-r f` | readable |
| `-w f` | writable |
| `-x f` | executable |
| `-s f` | non-empty |
| `-z s` | empty string |
| `-n s` | non-empty string |
| `a == b` | string equal (or glob with `=~`) |
| `a -eq b` | numeric equal |

## chmod numeric quick ref

| Want | Octal | Means |
|------|-------|-------|
| `rwx------` | 700 | private exec |
| `rw-------` | 600 | private file |
| `rwxr-xr-x` | 755 | binary / dir |
| `rw-r--r--` | 644 | normal file |
| `rwxrws---` | 2770 | shared dir, group inherit |
| `rwxrwxrwt` | 1777 | `/tmp` (sticky) |
