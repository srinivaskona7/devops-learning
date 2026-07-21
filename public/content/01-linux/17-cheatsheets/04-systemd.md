# systemd & journalctl — Cheatsheet

> systemd is not just an init system. It is a process supervisor, a logger, a timer, a network manager, a mount manager, and your new co-worker.

```text
   ┌─────────────────────────────────────────────────────────────┐
   │                    UNIT TYPES                               │
   │  .service   long-running daemon                             │
   │  .socket    socket-activated companion                      │
   │  .timer     scheduled trigger (modern cron)                 │
   │  .target    grouping (= runlevel)                           │
   │  .mount     mount point                                     │
   │  .path      filesystem-watch trigger                        │
   │  .slice     cgroup grouping for resource limits             │
   └─────────────────────────────────────────────────────────────┘

   STATES:  active (running) | inactive (dead) | failed
            activating       | deactivating    | reloading
   ENABLE:  enabled (will start at boot) | disabled | static | masked
```

---

## 1. systemctl — daily-driver commands

```bash
systemctl status nginx              # state + last 10 log lines + cgroup
systemctl start  nginx
systemctl stop   nginx
systemctl restart nginx             # stop + start
systemctl reload  nginx             # SIGHUP if unit defines ExecReload
systemctl reload-or-restart nginx   # reload if possible, else restart

systemctl enable  nginx             # start at boot (creates symlinks)
systemctl disable nginx
systemctl enable --now nginx        # enable + start in one shot
systemctl mask    nginx             # symlink to /dev/null — cannot be started
systemctl unmask  nginx

systemctl is-active   nginx         # exit 0 if active
systemctl is-enabled  nginx
systemctl is-failed   nginx

systemctl list-units --type=service --state=running
systemctl list-units --failed       # short list of broken things
systemctl list-unit-files --state=enabled
systemctl list-dependencies nginx   # tree of what nginx pulls in
```

## 2. Reading & editing units

```bash
systemctl cat      nginx            # show effective unit file (+ drop-ins)
systemctl show     nginx            # ALL properties (verbose)
systemctl show     nginx -p MainPID,ActiveState,MemoryCurrent
systemctl edit     nginx            # creates a drop-in override (preferred)
systemctl edit --full nginx         # edits the unit file directly
systemctl daemon-reload             # MUST run after editing files manually
systemctl revert   nginx            # discard drop-ins, back to vendor defaults
```

> **Drop-ins are the way.** Never edit a vendor unit in `/lib/systemd/system/` — it'll be overwritten on package upgrade. Use `systemctl edit <unit>` which writes to `/etc/systemd/system/<unit>.d/override.conf`.

## 3. Minimal unit file template

`/etc/systemd/system/myapp.service`

```ini
[Unit]
Description=My App
Documentation=https://example.com/docs
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=simple                    # simple | forking | oneshot | notify | exec | dbus
ExecStart=/opt/myapp/bin/server --config /etc/myapp.yaml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30s

# --- Security hardening ---
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
Environment=LOG_LEVEL=info
EnvironmentFile=-/etc/myapp/env       # leading - = ignore-if-missing
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ReadWritePaths=/var/lib/myapp /var/log/myapp
CapabilityBoundingSet=
AmbientCapabilities=

# --- Resource limits ---
LimitNOFILE=65536
MemoryMax=512M
CPUQuota=200%

[Install]
WantedBy=multi-user.target
```

### Key `Type=` semantics

| Type | systemd considers it "started" when... | Use for |
|------|----------------------------------------|---------|
| `simple` | The `ExecStart` process is forked | Most modern services |
| `forking` | The parent exits (true daemon) | Old-style daemons |
| `oneshot` | The process exits successfully | Run-and-done jobs (with `RemainAfterExit=yes`) |
| `notify` | The process sends `READY=1` via `sd_notify` | Services that need real readiness |
| `exec` | Like `simple` but waits for `execve()` to return | When `simple` is too eager |

## 4. Timers — modern cron

`/etc/systemd/system/backup.service`
```ini
[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
```

`/etc/systemd/system/backup.timer`
```ini
[Unit]
Description=Nightly backup

[Timer]
OnCalendar=*-*-* 02:30:00          # daily at 02:30
Persistent=true                     # run on next boot if missed
RandomizedDelaySec=15m              # avoid thundering herd
Unit=backup.service

[Install]
WantedBy=timers.target
```

```bash
systemctl enable --now backup.timer
systemctl list-timers --all          # next/last run for every timer
systemd-analyze calendar 'Mon..Fri 09:00'   # validate a calendar spec
```

## 5. journalctl — the one-stop log query

```bash
journalctl                          # all logs since boot
journalctl -u nginx                 # for a specific unit
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx --since "2025-01-01" --until "2025-01-02 12:00"
journalctl -u nginx -n 200          # last 200 lines
journalctl -u nginx -f              # follow (tail -f)
journalctl -u nginx -p err          # priority: err and worse
journalctl -u nginx -p warning..err # range
journalctl -u nginx -o json-pretty  # full structured record
journalctl -u nginx -o cat          # just the message text
journalctl _PID=1234                # by PID
journalctl _UID=1000
journalctl /usr/sbin/nginx          # by executable path
journalctl -k                       # kernel only (= dmesg)
journalctl -b                       # current boot
journalctl -b -1                    # previous boot
journalctl --list-boots             # all available boots
journalctl --disk-usage             # how much space am I using?
journalctl --vacuum-time=2weeks     # delete logs older than X
journalctl --vacuum-size=500M       # cap on-disk size
journalctl --grep='timeout' -u nginx
```

### Priority levels (`-p`)

```text
0 emerg  1 alert  2 crit  3 err  4 warning  5 notice  6 info  7 debug
```

## 6. Targets, isolation, and boot

```bash
systemctl get-default                     # default target (graphical/multi-user)
systemctl set-default multi-user.target   # boot to text mode
systemctl isolate rescue.target           # switch NOW (live) — careful
systemctl reboot
systemctl poweroff
systemctl suspend
```

## 7. Boot performance

```bash
systemd-analyze                       # total + userspace + kernel time
systemd-analyze blame                 # slowest units, highest first
systemd-analyze critical-chain        # serialized critical path
systemd-analyze plot > boot.svg       # visual chart
```

## 8. Resource accounting (cgroups v2)

```bash
systemd-cgtop                         # top, but per-cgroup (= per-service)
systemctl status nginx                # MemoryCurrent, CPUUsageNSec, Tasks
systemctl set-property nginx MemoryMax=512M CPUQuota=150%   # live, persists
systemctl set-property nginx MemoryMax=                      # reset (live)
```

## 9. Common errors & fixes

| Error in `systemctl status` / journal | Likely cause | Fix |
|---|---|---|
| `Failed to start ... Unit not found` | Missing file; or after edit, no `daemon-reload` | `daemon-reload`; check `systemctl cat` |
| `status=203/EXEC` | Binary path wrong / not executable | `ls -l` the path; check shebang |
| `status=200/CHDIR` | `WorkingDirectory` doesn't exist | Create it; check permissions |
| `status=217/USER` | `User=` doesn't exist | Create user or fix name |
| `Start request repeated too quickly` | Crash loop hit `StartLimitBurst` | Fix root cause; `systemctl reset-failed unit` |
| `Failed at step NAMESPACE` | `ProtectSystem`/`PrivateTmp` blocking write | Add `ReadWritePaths=`; or relax |
| Active but app doesn't work | `Type=simple` returns "started" instantly | Use `Type=notify` + `sd_notify` |
| Unit "loaded but inactive (dead)" after `enable` | Forgot `--now`, or `[Install]` missing | `systemctl start ...`; add `WantedBy=` |

## 10. Debugging mantra (in order)

```bash
systemctl status <unit>                            # 1. state + recent log
journalctl -u <unit> -n 100 --no-pager             # 2. more log
journalctl -u <unit> -p err -b                     # 3. errors this boot
systemctl cat <unit>                                # 4. effective config
systemd-analyze verify /etc/systemd/system/<u>     # 5. lint the unit
systemd-run --uid=svc-user -- /opt/app/bin --flag  # 6. run by hand same way
```

---

## ★ If you remember nothing else ★

```bash
1.  systemctl edit <unit>          — drop-ins, never edit vendor files.
2.  systemctl daemon-reload        — after EVERY manual file edit.
3.  journalctl -u <unit> -f        — your tail -f.
4.  systemctl status <unit>        — first stop on every "is it broken?".
5.  Type=simple is "I forked" not "I'm ready". Use notify for real readiness.
```
