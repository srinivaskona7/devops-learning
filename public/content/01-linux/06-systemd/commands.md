# systemd — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# systemd-enabled container (vanilla docker has no systemd PID 1)
docker run -it --rm --privileged --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw jrei/systemd-ubuntu:22.04
```

## Core commands

```bash
# Status of a unit (active state, recent logs)
systemctl status nginx
```

```bash
# Boolean state checks
systemctl is-active nginx
systemctl is-enabled nginx
```

```bash
# Show effective unit config including drop-ins
systemctl cat nginx.service
```

```bash
# Inspect specific properties of a running unit
systemctl show nginx -p MainPID,ExecStart,Restart
```

```bash
# Lifecycle controls
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx
```

```bash
# Boot-time enable/disable
systemctl enable nginx
systemctl disable nginx
```

```bash
# Enable AND start in one step
systemctl enable --now nginx
```

```bash
# MUST run after editing any unit file
systemctl daemon-reload
```

```bash
# Open editor that creates a drop-in override
systemctl edit nginx
```

```bash
# List running services
systemctl list-units --type=service --state=running
```

```bash
# List enabled unit files
systemctl list-unit-files --state=enabled
```

```bash
# All timers (cron replacement) with next-fire
systemctl list-timers --all
```

```bash
# All logs for a unit
journalctl -u nginx
```

```bash
# Follow new log lines (tail -f equivalent)
journalctl -u nginx -f
```

```bash
# Time-window filter
journalctl -u nginx --since '1 hour ago'
```

```bash
# Priority filter (emerg..debug range syntax)
journalctl -u nginx -p err..alert
```

```bash
# This boot only / previous boot
journalctl -b
journalctl -b -1
```

```bash
# Boot performance: total + per-service blame
systemd-analyze
systemd-analyze blame
```

## Inspection / verification

```bash
# Confirm restart policy fired with new MainPID after a kill
systemctl show -p MainPID --value heartbeat
```

```bash
# Default boot target (multi-user.target on servers)
systemctl get-default
```

```bash
# Disk used by journal logs
journalctl --disk-usage
```

```bash
# Validate a calendar timer expression
systemd-analyze calendar 'Mon *-*-* 03:00:00'
```

## Cleanup

```bash
# Stop, disable, then remove the unit file
systemctl disable --now heartbeat.service
rm /etc/systemd/system/heartbeat.service
systemctl daemon-reload
```

```bash
# Prune logs older than 7 days
journalctl --vacuum-time=7d
```

## One-liners worth memorising

```bash
# Tail logs for a unit since the alert fired
journalctl -u myapp --since '15 min ago' -f
```

```bash
# Reload-and-restart pattern after editing a unit
systemctl daemon-reload && systemctl restart myapp && systemctl status myapp --no-pager
```

```bash
# Ten slowest services at boot
systemd-analyze blame | head -10
```

```bash
# Find every failed unit on the system
systemctl --failed
```

```bash
# Send a polite reload (SIGHUP) instead of restart
systemctl reload nginx
```
