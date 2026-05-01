# Package Management — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Throwaway Debian-family shell
docker run -it --rm ubuntu:22.04 bash
```

## Core commands

### Debian / Ubuntu — apt + dpkg

```bash
# Refresh package metadata (always before install on a fresh container)
apt update
```

```bash
# Upgrade installed packages without removing anything
apt upgrade -y
```

```bash
# Install one or more packages
apt install -y nginx jq
```

```bash
# Remove (keep configs) vs purge (remove configs too)
apt remove -y nginx
apt purge  -y nginx
```

```bash
# Drop orphaned dependencies
apt autoremove -y
```

```bash
# Search and inspect
apt search nginx
apt show nginx
```

```bash
# Pin / unpin a package version
apt-mark hold nginx
apt-mark unhold nginx
```

```bash
# Which package owns this file
dpkg -S /etc/nginx/nginx.conf
```

```bash
# List files installed by a package
dpkg -L nginx
```

```bash
# Install a local .deb
dpkg -i pkg.deb
```

### RHEL / Fedora / Rocky — dnf + rpm

```bash
# Refresh + upgrade
dnf check-update
dnf upgrade -y
```

```bash
# Install / remove / search
dnf install -y nginx jq
dnf remove  -y nginx
dnf search nginx
```

```bash
# Transaction history + rollback
dnf history
dnf history undo <id>
```

```bash
# Find what provides a binary or path
dnf provides /usr/sbin/nginx
```

```bash
# rpm-level inspection
rpm -qa | grep nginx
rpm -ql nginx
rpm -qf /usr/sbin/nginx
```

### Arch — pacman

```bash
# Sync repos + upgrade everything
pacman -Syu
```

```bash
# Install / remove + unused deps + configs
pacman -S nginx
pacman -Rns nginx
```

```bash
# Search / list / find owner
pacman -Ss nginx
pacman -Q
pacman -Qo /usr/bin/nginx
```

### macOS / Linux — brew

```bash
# Refresh + upgrade
brew update && brew upgrade
```

```bash
# Install / remove / search
brew install jq
brew uninstall jq
brew search jq
```

```bash
# Manage services on macOS
brew services start postgresql
```

```bash
# Reclaim disk by purging old versions
brew cleanup
```

## Inspection / verification

```bash
# Confirm install + version
jq --version
```

```bash
# Show held (pinned) packages on apt
apt-mark showhold
```

```bash
# Inspect configured apt source list
ls /etc/apt/sources.list.d/ && cat /etc/apt/sources.list | head
```

```bash
# Quick "is it installed" check by exit code
apt list --installed 2>/dev/null | grep -q '^nginx/' && echo yes || echo no
```

## Cleanup

```bash
# Purge + autoremove orphans
apt purge -y jq tree && apt autoremove -y
```

```bash
# Slim Docker images: drop apt cache after install
rm -rf /var/lib/apt/lists/*
```

## One-liners worth memorising

```bash
# Dockerfile-friendly install (no recommends, clean cache)
apt-get update && apt-get install -y --no-install-recommends nginx && rm -rf /var/lib/apt/lists/*
```

```bash
# Find which package shipped a binary
dpkg -S "$(which nginx)" || rpm -qf "$(which nginx)"
```

```bash
# List files a package installed
dpkg -L nginx | grep -v '/$'
```

```bash
# Pin a critical package across upgrades
apt-mark hold openssh-server
```
