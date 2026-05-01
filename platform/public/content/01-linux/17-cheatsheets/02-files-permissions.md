# Files & Permissions — Cheatsheet

> Permission denied isn't an error. It's a question: "are you sure you should be doing this?"

```text
   MODE BITS — 16 bits, displayed as 4 octal digits

   ┌─────────┬─────────────────────────────────────────┐
   │  S U G T│  setuid  setgid  sticky  (special bits) │
   ├─────────┼─────────────────────────────────────────┤
   │  r w x  │  USER     (owner)                       │
   │  r w x  │  GROUP                                  │
   │  r w x  │  OTHER    (everyone else)               │
   └─────────┴─────────────────────────────────────────┘

   Example:  -rwsr-xr-x   →  4755   →  setuid binary, owner rwx, others r-x
             drwxrwxrwt   →  1777   →  /tmp (sticky bit)
             -rw-r-----   →  0640   →  typical secret file
```

---

## 1. Octal mode reference

| Octal | Binary | rwx | Meaning |
|:-:|:-:|:-:|---|
| 0 | 000 | --- | nothing |
| 1 | 001 | --x | execute only |
| 2 | 010 | -w- | write only |
| 3 | 011 | -wx | write+execute |
| 4 | 100 | r-- | read only |
| 5 | 101 | r-x | read+execute |
| 6 | 110 | rw- | read+write |
| 7 | 111 | rwx | all |

**Compute by adding:** 4 (read) + 2 (write) + 1 (execute).

| Special (leading digit) | Bit | Symbol shown |
|---|---|---|
| 4 | setuid | `s` in user-x slot (`S` if no x) |
| 2 | setgid | `s` in group-x slot |
| 1 | sticky | `t` in other-x slot |

## 2. Common chmod recipes

| Goal | Symbolic | Octal |
|------|----------|-------|
| Private file (only you read/write) | `chmod u=rw,go= file` | `chmod 600 file` |
| Shared-read (your group reads) | `chmod u=rw,g=r,o= file` | `chmod 640 file` |
| Public read | `chmod a+r file` | `chmod 644 file` |
| Make executable | `chmod +x script.sh` | `chmod 755 script.sh` |
| Strip world access | `chmod o= path` | (no clean octal) |
| Recursive, dirs 755 / files 644 | `chmod -R u+rwX,go+rX,go-w path` | use `find` (below) |
| Sticky bit on shared dir | `chmod +t /shared` | `chmod 1777 /shared` |
| setgid on dir (inherit group) | `chmod g+s /shared` | `chmod 2775 /shared` |

> **The capital `X` trick:** `X` means "execute, but only on directories or files that already have some `x` bit set." This is how you sanely fix tarballs that lost their bits.

## 3. ACLs (when chmod isn't enough)

```bash
getfacl /srv/app                    # show
setfacl -m u:alice:rwx /srv/app     # alice gets rwx in addition
setfacl -m g:devs:rx  /srv/app
setfacl -m d:u:alice:rwx /srv/app   # default ACL — inherited by new files
setfacl -x u:alice    /srv/app      # remove an entry
setfacl -b /srv/app                 # strip all ACLs
```

A `+` after the mode in `ls -l` (e.g. `-rw-r--r--+`) means an ACL is present.

## 4. ownership

```bash
chown alice file               # owner
chown alice:devs file          # owner + group
chown -R --from=bob alice /srv # only files currently owned by bob
chgrp devs file
```

`chown` is root-only. `chgrp` works as a non-root user **only** if you own the file **and** are a member of the target group.

## 5. umask — the inverse mask

```text
File default = 0666 & ~umask
Dir  default = 0777 & ~umask

umask 022  → files 644, dirs 755   (typical desktop)
umask 027  → files 640, dirs 750   (typical server)
umask 077  → files 600, dirs 700   (single-user / secrets)
```

Set per-user in `~/.bashrc`; per-service in the systemd unit (`UMask=0027`).

## 6. `find` — by mode, time, size, owner

### By mode

```bash
find /etc -perm 644              # exactly 644
find /etc -perm -644             # at least these bits set (and possibly more)
find /etc -perm /u+w             # any of: user-write set
find / -perm -4000 -type f       # all setuid files (audit me!)
find / -perm -2000 -type f       # all setgid files
find / -perm -1000 -type d       # all sticky directories
find . -perm /o+w -type f        # world-writable files (BAD)
```

### By time (the trap: `mtime` is in **24h units**)

| Flag | Meaning |
|------|---------|
| `-mtime -7` | Modified within last 7 days |
| `-mtime +30` | Modified more than 30 days ago |
| `-mtime 0` | Modified in the last 24h |
| `-mmin -60` | Modified in the last 60 min |
| `-atime`, `-ctime` | Same units, access / inode-change |
| `-newer ref` | More recently modified than `ref` |

### By size

```bash
find /var/log -size +100M             # bigger than 100 megabytes
find /var/log -size -1k                # smaller than 1 kilobyte
find / -size +1G -type f -printf '%s\t%p\n' | sort -rn | head
```

### By owner / orphan

```bash
find / -nouser -o -nogroup        # files with no matching user/group
find /home -user alice -type f
find . -group devs
```

### Acting on results

```bash
# slowest, but safe with weird filenames:
find . -name '*.log' -exec gzip {} \;

# faster — one process for many files:
find . -name '*.log' -exec gzip {} +

# fastest, parallel-safe, NUL-delimited:
find . -name '*.log' -print0 | xargs -0 -P4 -n50 gzip
```

## 7. The "safe defaults" recipe

When you inherit a chaotic directory tree:

```bash
find /srv/app -type d -exec chmod 750 {} +
find /srv/app -type f -exec chmod 640 {} +
find /srv/app -type f -name '*.sh' -exec chmod 750 {} +
chown -R app:app /srv/app
```

## 8. Capabilities (the modern alternative to setuid)

```bash
getcap /usr/bin/ping
# /usr/bin/ping cap_net_raw=ep

setcap 'cap_net_bind_service=+ep' /opt/app/bin/server   # bind <1024 without root
setcap -r /path/to/binary                                # remove
```

Prefer capabilities to setuid — much smaller blast radius.

## 9. Useful one-liners

```bash
# largest files by size, top 20
find / -xdev -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -20

# files modified in the last hour anywhere under /etc
sudo find /etc -mmin -60 -type f

# audit world-writable files outside /tmp
find / -xdev -path /proc -prune -o -perm /o+w -type f -print

# diff permissions between two trees
diff <(cd /a && find . -printf '%m %p\n' | sort) \
     <(cd /b && find . -printf '%m %p\n' | sort)
```

---

## ★ If you remember nothing else ★

```bash
1.  4=r 2=w 1=x.  Add them.  640 = rw- r-- ---
2.  chmod -R u+rwX,go+rX  fixes broken tarballs.
3.  find -perm -4000 -type f   audits setuid binaries.
4.  find -mtime is in DAYS, -mmin is in MINUTES.
5.  Prefer setcap over chmod u+s.  Smaller blast radius.
```
