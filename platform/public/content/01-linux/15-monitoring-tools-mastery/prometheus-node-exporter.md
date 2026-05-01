# Prometheus node_exporter — turning a Linux box into time-series data

## Why this matters

Live tools (`top`, `vmstat`, `atop`) tell you what's happening **now** or what happened **on this box**. But once you have more than ~5 servers, you need:

- a single place to query "what was the disk write rate on every web server at 03:14?";
- alerting that fires when patterns appear, not when humans notice;
- dashboards that compare across hosts and time.

`node_exporter` is the de facto answer. It is a single Go binary that exposes ~1000+ Linux metrics on `:9100/metrics` in Prometheus format. It is the most-deployed exporter in the world and the foundation of every "Linux dashboard" in Grafana.

```mermaid
flowchart LR
    Kernel[/proc, /sys, netlink] --> NE[node_exporter]
    Custom[Cron jobs, scripts] --> TF[textfile collector<br>/var/lib/node_exporter/textfile_collector/*.prom]
    TF --> NE
    NE -->|HTTP :9100/metrics| P[Prometheus]
    P --> G[Grafana]
    P --> AM[Alertmanager]
```

---

## Install

```bash
# Tarball (cleanest)
VER=1.8.2
wget https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-amd64.tar.gz
tar xf node_exporter-${VER}.linux-amd64.tar.gz
sudo mv node_exporter-${VER}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter
```

Systemd unit `/etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown -R node_exporter: /var/lib/node_exporter
sudo systemctl daemon-reload && sudo systemctl enable --now node_exporter
curl -s localhost:9100/metrics | head
```

---

## What node_exporter exposes (the >1000 metrics)

Collectors are toggleable. Defaults cover ~95% of needs. Categories:

| Collector | Examples | Comment |
|-----------|----------|---------|
| `cpu` | `node_cpu_seconds_total{cpu,mode}` | per-CPU per-mode counters |
| `loadavg` | `node_load1`, `node_load5`, `node_load15` | gauge |
| `meminfo` | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes`, ~50 others | every line of /proc/meminfo |
| `diskstats` | `node_disk_reads_completed_total`, `node_disk_io_time_seconds_total`, `node_disk_read_bytes_total` | per-device |
| `filesystem` | `node_filesystem_avail_bytes`, `node_filesystem_size_bytes` | per mount |
| `netdev` | `node_network_receive_bytes_total`, `..._transmit_bytes_total`, `..._receive_errs_total` | per interface |
| `netstat` | `node_netstat_Tcp_CurrEstab` | /proc/net/netstat |
| `sockstat` | TCP/UDP socket counts | |
| `vmstat` | `node_vmstat_pgfault`, `node_vmstat_pswpin`, `node_vmstat_oom_kill` | every line of /proc/vmstat |
| `pressure` | `node_pressure_cpu_waiting_seconds_total`, `..._memory_..`, `..._io_..` | PSI (kernel ≥ 4.20) |
| `systemd` | `node_systemd_unit_state{state="active"}` | per unit |
| `processes` | `node_processes_state{state="R/S/D/Z"}` | enabled with `--collector.processes` |
| `hwmon`, `thermal_zone` | `node_hwmon_temp_celsius` | hardware temps |
| `nvme` | NVMe SMART | needs `--collector.nvme` |
| `textfile` | `node_textfile_*` | your custom metrics |

Full list: `curl -s localhost:9100/metrics | grep '^# HELP' | wc -l` will be ~600–1500 depending on hardware.

---

## The textfile collector — custom metrics on the cheap

This is the killer feature. The exporter reads any `*.prom` file in the textfile directory and exposes their contents as if it produced them. Use it for:

- backup completion timestamps
- last-rsync exit codes
- batch job durations
- anything cron produces

### Example: track package update lag

`/etc/cron.hourly/apt_metrics`:

```bash
#!/bin/bash
set -euo pipefail
DIR=/var/lib/node_exporter/textfile_collector
mkdir -p "$DIR"
TMP=$(mktemp)

cat <<EOF > "$TMP"
# HELP node_apt_upgrades_pending Pending package upgrades
# TYPE node_apt_upgrades_pending gauge
node_apt_upgrades_pending $(apt list --upgradable 2>/dev/null | wc -l)
# HELP node_apt_security_upgrades_pending Pending security upgrades
# TYPE node_apt_security_upgrades_pending gauge
node_apt_security_upgrades_pending $(apt list --upgradable 2>/dev/null | grep -c security || true)
EOF

mv "$TMP" "$DIR/apt.prom"   # atomic rename → no torn reads
```

### Example: backup health

```bash
END=$(date +%s)
cat <<EOF > /var/lib/node_exporter/textfile_collector/backup.prom.tmp
# HELP node_backup_last_success_timestamp Unix time of last backup success
# TYPE node_backup_last_success_timestamp gauge
node_backup_last_success_timestamp $END
# HELP node_backup_duration_seconds Last backup duration in seconds
# TYPE node_backup_duration_seconds gauge
node_backup_duration_seconds $DURATION
# HELP node_backup_size_bytes Size of last backup in bytes
# TYPE node_backup_size_bytes gauge
node_backup_size_bytes $SIZE
EOF
mv /var/lib/node_exporter/textfile_collector/backup.prom{.tmp,}
```

Then alert on `time() - node_backup_last_success_timestamp > 86400`.

> **Always write to a tempfile and `mv`** — node_exporter reads the file mid-write otherwise.

---

## PromQL recipes against node_exporter

### CPU

```promql
# CPU utilisation per host (1 - idle)
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

# % steal (noisy neighbour on VM)
avg by (instance) (rate(node_cpu_seconds_total{mode="steal"}[5m]))

# Per-CPU saturation: top CPU on each host
max by (instance) (1 - rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

### Memory

```promql
# Memory pressure (don't use 1 - free; cache lies)
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# OOM kills in last hour
increase(node_vmstat_oom_kill[1h]) > 0

# Swapping rate
rate(node_vmstat_pswpin[5m]) + rate(node_vmstat_pswpout[5m])
```

### Disk

```promql
# Disk usage % (exclude tmpfs/overlay)
100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}
            / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs"})

# Predict: full in 4h?
predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0

# Disk IO saturation
rate(node_disk_io_time_seconds_total[5m])  # 0..1 per device

# Per-device throughput MB/s
rate(node_disk_read_bytes_total[5m]) / 1024 / 1024
rate(node_disk_written_bytes_total[5m]) / 1024 / 1024
```

### Network

```promql
# RX/TX bandwidth Mbit/s
rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*"}[5m]) * 8 / 1e6
rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*"}[5m]) * 8 / 1e6

# NIC errors (any > 0 should investigate)
rate(node_network_receive_errs_total[5m]) > 0
rate(node_network_transmit_errs_total[5m]) > 0

# TCP retransmits per second
rate(node_netstat_Tcp_RetransSegs[5m])
```

### Load & PSI

```promql
# Load per core (>1 = saturated)
node_load5 / count by (instance) (node_cpu_seconds_total{mode="idle"})

# PSI — pressure stall info (kernel ≥4.20)
rate(node_pressure_cpu_waiting_seconds_total[5m])     # CPU pressure
rate(node_pressure_memory_waiting_seconds_total[5m])  # mem pressure
rate(node_pressure_io_waiting_seconds_total[5m])      # IO pressure
```

PSI is the modern saturation metric. > 0.1 sustained = users feel it.

### Systemd

```promql
# Any unit failed?
node_systemd_unit_state{state="failed"} == 1
```

### Up / scrape health

```promql
# Host down (no scrape for >2 minutes)
up{job="node"} == 0

# Slow scrape (exporter overloaded)
scrape_duration_seconds{job="node"} > 5
```

---

## Lab: full local Prometheus + node_exporter loop

```bash
# 1) node_exporter already running on :9100

# 2) Run prometheus in docker pointed at it
mkdir -p /tmp/prom
cat > /tmp/prom/prometheus.yml <<'EOF'
global:
  scrape_interval: 5s
scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['host.docker.internal:9100']
EOF

docker run -d --name prom -p 9090:9090 \
  -v /tmp/prom/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# 3) Generate signal
stress-ng --cpu 4 --vm 2 --vm-bytes 1G --hdd 2 --timeout 120s &

# 4) Query
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))' | jq .

# 5) Push a custom metric via textfile
echo "lab_value $(date +%s)" | sudo tee /var/lib/node_exporter/textfile_collector/lab.prom
curl -s localhost:9100/metrics | grep lab_value
```

---

!!! tip "20-year tips"
    1. **Always run `node_exporter` as a non-root systemd service.** Never as root, never inside the app container.
    2. **Atomic write to textfiles (`mv` from temp).** Otherwise the exporter reads half-written files and breaks the scrape.
    3. **Use `node_memory_MemAvailable_bytes`, not `MemFree_bytes`.** "Free" excludes reclaimable cache; available is the truth.
    4. **For disk fill alerts, `predict_linear` beats threshold.** "Will be full in 4h at current rate" is more actionable than "is 80% full".
    5. **Enable PSI collectors.** PSI is the kernel's own saturation signal and beats every ad-hoc heuristic.
    6. **Use `--collector.systemd --collector.systemd.unit-include='(my-app|nginx).service'`** — the default scrapes every unit and bloats cardinality.
    7. **Don't expose `:9100` to the internet.** Bind to localhost or to a wireguard interface; scrape over private network.
    8. **Disable collectors you don't use** with `--no-collector.<name>`. Reduces scrape time and metric churn.
    9. **`scrape_duration_seconds` is your canary** — when it climbs, the exporter is sick (or you enabled too many collectors).

!!! question "Common interview questions"
    **Q1: How does node_exporter expose metrics?**
    A: HTTP server on `:9100/metrics` in Prometheus text format. Prometheus scrapes by HTTP GET on a configurable interval.

    **Q2: Difference between `MemFree` and `MemAvailable`?**
    A: `MemFree` is RAM not used at all. `MemAvailable` is RAM that can be given to a new process without swapping (free + reclaimable cache). Always use `MemAvailable` for capacity decisions.

    **Q3: How do you add custom application metrics without writing a custom exporter?**
    A: Textfile collector — write a `.prom` file in Prometheus format to the configured directory; node_exporter exposes it. Use `mv` from a tempfile to avoid torn reads.

    **Q4: Why is `1 - rate(node_cpu_seconds_total{mode="idle"}[5m])` better than just summing user+system?**
    A: It accounts for all non-idle modes (user, system, iowait, irq, softirq, steal, guest). Plus it's symmetric: idle is one number; non-idle is everything else.

    **Q5: What's the textfile collector "atomic write" pattern and why?**
    A: Write to `/path/foo.prom.tmp`, then `mv` to `/path/foo.prom`. Rename is atomic in POSIX, so the exporter never sees a half-written file.

    **Q6: How do you predict when a disk will fill?**
    A: `predict_linear(node_filesystem_avail_bytes[6h], 4*3600) < 0` — extrapolate the trend over the last 6 hours, alert if it crosses zero in the next 4 hours.

    **Q7: What is PSI and why is it useful?**
    A: Pressure Stall Information — kernel exposes `/proc/pressure/{cpu,memory,io}` showing how long tasks stalled on each resource. It's the most direct measure of saturation. node_exporter's `pressure` collector exposes it.

    **Q8: How do you scrape securely?**
    A: TLS + basic auth via the exporter's web config file (`--web.config.file=...`); or front it with reverse proxy; or scrape over a private network only. Never expose 9100 to the internet.

---

## Sources

- [github.com/prometheus/node_exporter](https://github.com/prometheus/node_exporter)
- [Prometheus best practices — exporters](https://prometheus.io/docs/practices/naming/)
- [Textfile collector](https://github.com/prometheus/node_exporter#textfile-collector)
- [PSI documentation](https://www.kernel.org/doc/html/latest/accounting/psi.html)
- [PromQL functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- Brian Brazil, *Prometheus: Up & Running* (O'Reilly)
