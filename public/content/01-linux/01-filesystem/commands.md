# Linux Filesystem — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Spin a throwaway Ubuntu shell with tree + file installed
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y tree file >/dev/null
```

## Core commands

```bash
# Print absolute working directory
pwd
```

```bash
# Long listing with hidden files + human-readable sizes
ls -lah /etc
```

```bash
# Jump back to the previous directory
cd -
```

```bash
# Show 2 levels of /var as a tree
tree -L 2 /var
```

```bash
# Inode, perms, atime/mtime/ctime, blocks
stat /etc/hosts
```

```bash
# Identify file type (ELF, script, data, ...)
file /bin/ls
```

```bash
# Disk free with filesystem type column
df -hT
```

```bash
# Per-entry size summary, human readable
du -sh /var/log/*
```

```bash
# Tree view of all mounts
findmnt
```

```bash
# Hard link — same inode, can't cross filesystems
ln /etc/hosts hardlink
```

```bash
# Symbolic link — path-based, can cross filesystems and break
ln -s /etc/hosts symlink
```

```bash
# Resolve symlink to absolute target
readlink -f symlink
```

```bash
# Canonicalize a path (resolves .. and symlinks)
realpath ./foo/../bar
```

```bash
# Find /etc files modified in last day (suppress permission errors)
find /etc -type f -mtime -1 2>/dev/null
```

## Inspection / verification

```bash
# Show inode + link count for a file
stat original.txt | grep -E 'Inode|Links'
```

```bash
# List with inode column to compare hard vs soft links
ls -li *.txt
```

```bash
# Inspect kernel-exposed CPU info
cat /proc/cpuinfo | head
```

```bash
# Status of the current shell process ($$ = PID)
cat /proc/$$/status
```

```bash
# Open file descriptors of current shell
ls /proc/$$/fd
```

```bash
# Confirm a tmpfs mount
findmnt /dev/shm
```

## Cleanup

```bash
# Remove the test files
rm -f /tmp/original.txt /tmp/hard.txt /tmp/soft.txt
```

```bash
# Exit the throwaway container — auto-removed by --rm
exit
```

## One-liners worth memorising

```bash
# Top 10 biggest things under a dir, sorted human-readable
du -h --max-depth=1 / 2>/dev/null | sort -rh | head
```

```bash
# Find leaked deleted-but-open files eating disk
lsof | grep deleted
```

```bash
# Resolve where a symlink ultimately points
readlink -f /usr/bin/python
```

```bash
# Show MAC address of an interface via /sys
cat /sys/class/net/eth0/address
```

```bash
# Print PID of current shell, then its executable path
echo $$ && ls -l /proc/$$/exe
```
