# Users & Permissions — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway Ubuntu shell with sudo + vim
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y sudo vim >/dev/null
```

## Core commands

```bash
# Show your uid, gid, and groups
id
```

```bash
# Create user with home dir and bash shell
useradd -m -s /bin/bash alice
```

```bash
# Set or change user password (interactive)
passwd alice
```

```bash
# Set password non-interactively from a script
echo 'alice:Welcome1!' | chpasswd
```

```bash
# Append alice to the sudo supplementary group (-a is critical)
usermod -aG sudo alice
```

```bash
# Delete user AND remove home + mail spool
userdel -r alice
```

```bash
# Create a new group
groupadd developers
```

```bash
# Add a user to a group via gpasswd
gpasswd -a alice developers
```

```bash
# Numeric chmod: rwx for owner, r-x for group, none for other
chmod 750 script.sh
```

```bash
# Symbolic chmod: add owner exec, drop group write, clear other
chmod u+x,g-w,o= file
```

```bash
# Recursive read for group; capital X = exec only on dirs/already-exec
chmod -R g+rX dir
```

```bash
# Set owner and group at once
chown alice:developers report.txt
```

```bash
# View / set umask (bits stripped from new file perms)
umask 0077
```

```bash
# Setuid: run binary as file owner (e.g. passwd)
chmod u+s /usr/bin/passwd
```

```bash
# Setgid on directory: new files inherit the dir group
chmod g+s shared_dir
```

```bash
# Sticky bit: only owner can delete their own files (think /tmp)
chmod +t /tmp
```

```bash
# Numeric form: 2770 = setgid + rwxrwx---
chmod 2770 /srv/project
```

```bash
# List what current user can sudo
sudo -l
```

```bash
# Run a command as another user
sudo -u postgres psql
```

```bash
# Safely edit a sudoers fragment (syntax-checks on save)
visudo -f /etc/sudoers.d/alice
```

## Inspection / verification

```bash
# Who is logged in right now
who
```

```bash
# Last 5 logins from /var/log/wtmp
last -n 5
```

```bash
# Verify alice's record in /etc/passwd
grep alice /etc/passwd
```

```bash
# Verify password hash entry (root only)
grep alice /etc/shadow
```

```bash
# Confirm sticky bit on /tmp (trailing 't')
ls -ld /tmp
```

```bash
# Find files owned by a specific uid (orphans audit)
find / -uid 1000 2>/dev/null
```

## Cleanup

```bash
# Remove user + home, then group
userdel -r alice
groupdel developers
```

```bash
# Remove sudoers fragment
rm -f /etc/sudoers.d/alice
```

## One-liners worth memorising

```bash
# Restrictive umask: only owner can read new files
umask 0077
```

```bash
# Create a shared group-writable project dir with setgid
mkdir /srv/project && chown root:developers /srv/project && chmod 2770 /srv/project
```

```bash
# Grant a user one specific NOPASSWD command
echo 'alice ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx' > /etc/sudoers.d/alice && chmod 440 /etc/sudoers.d/alice
```

```bash
# Run command as another user with a clean login shell env
su - alice -c 'whoami && pwd'
```
