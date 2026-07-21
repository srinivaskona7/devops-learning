# Log Analysis — finding the needle in the haystack

## Why this matters

Metrics tell you **that** something is broken. Logs tell you **what** broke. After 20 years on call, the engineer who can grep `journalctl` faster than someone can open Kibana wins more incidents. Logs are also the only artifact that survives reboots, container restarts, and infrastructure churn — if you store them right.

This file covers the four pillars: **collecting** (journald, rsyslog, syslog-ng), **viewing** (journalctl, lnav, multitail), **rotating** (logrotate), and **shipping** (Loki, ELK).

```mermaid
flowchart LR
    Apps -->|stdout| Container[Container runtime]
    Apps -->|syslog| Syslog[rsyslog/syslog-ng]
    Apps -->|sd_journal| Journald
    Container --> Journald
    Syslog --> Files[/var/log/*.log]
    Journald --> JBin[/var/log/journal/*.journal]
    Files --> Promtail
    Files --> Filebeat
    JBin --> Promtail
    JBin --> Vector
    Promtail --> Loki
    Filebeat --> Logstash --> ES[Elasticsearch]
    Vector --> Loki
    Vector --> ES
```

---

## journalctl — the Swiss army knife

### Filtering basics

```bash
# Time-based
journalctl --since "1 hour ago"
journalctl --since "2026-04-26 03:00" --until "2026-04-26 04:00"
journalctl --since yesterday --until today

# Unit-based
journalctl -u nginx.service
journalctl -u nginx -f               # tail -f
journalctl -u nginx --since today

# Boot-based
journalctl -b                         # this boot
journalctl -b -1                      # previous boot
journalctl --list-boots

# Priority (RFC 5424)
journalctl -p err                    # err and worse (err, crit, alert, emerg)
journalctl -p warning..err           # range

# Process / user / executable
journalctl _PID=1234
journalctl _UID=1000
journalctl /usr/bin/sshd

# Kernel only
journalctl -k

# Output formats
journalctl -o json
journalctl -o json-pretty
journalctl -o cat                     # message only, no metadata
journalctl -o short-iso               # ISO8601 timestamps (preferred)
```

### Field discovery

```bash
journalctl --fields                  # list all available fields
journalctl -F _SYSTEMD_UNIT          # all unique values of a field
journalctl _COMM=ssh _PRIORITY=3     # combine
```

### Persistence (do this on every box)

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
journalctl --disk-usage              # how big
sudo journalctl --vacuum-time=30d    # cleanup
sudo journalctl --vacuum-size=2G
```

`/etc/systemd/journald.conf`:

```ini
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemMaxFileSize=200M
MaxRetentionSec=30day
ForwardToSyslog=no
```

### Common one-liners

```bash
# All sshd auth failures today
journalctl -u ssh --since today | grep -iE 'failed|invalid'

# Top error sources in last hour
journalctl --since "1 hour ago" -p err -o json | jq -r ._SYSTEMD_UNIT | sort | uniq -c | sort -rn

# Was the box OOM-killed?
journalctl -k | grep -i 'killed process'

# Last 50 lines of a unit, with full metadata
journalctl -u myapp -n 50 -o verbose
```

---

## lnav — the navigator

**Install**: `apt install lnav`.

```bash
lnav /var/log/syslog
lnav /var/log/nginx/*.log
lnav /var/log/{syslog,auth.log,kern.log}    # multiple files merged by timestamp
lnav -r https://example.com/foo.log         # remote
journalctl -o json | lnav                   # pipe in
```

**Why it's special**:
- Auto-detects log formats (nginx, apache, syslog, journald, JSON).
- **SQL queries against logs**: press `;` then `SELECT log_level, COUNT(*) FROM access_log GROUP BY log_level`.
- Histogram view: press `i` for a time-bucketed counts view.
- Filters: `:filter-out 200`, `:filter-in error`.
- `q` to quit.

It's `tail -F` + `grep` + `awk` + `sqlite` over your logs.

---

## multitail

**Install**: `apt install multitail`.

```bash
multitail /var/log/syslog /var/log/auth.log
multitail -i /var/log/syslog -i /var/log/kern.log    # vertical split
multitail -l "ping -i 1 8.8.8.8" -l "ping -i 1 1.1.1.1"  # tail commands
```

Color-coded, multi-pane `tail -F`. Indispensable when watching two correlated logs (e.g., nginx + app) on the same screen.

---

## logrotate — the housekeeper

`/etc/logrotate.d/myapp`:

```bash
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    create 0640 myapp myapp
    postrotate
        /bin/systemctl reload myapp.service > /dev/null 2>&1 || true
    endscript
}
```

**Key directives**:

| Directive | Meaning |
|-----------|---------|
| `daily` / `weekly` / `monthly` / `size 100M` | rotate trigger |
| `rotate N` | keep N old files |
| `compress` | gzip rotated files |
| `delaycompress` | wait one cycle (so today's `.1` is plain text, easier to grep) |
| `missingok` | don't error if file missing |
| `notifempty` | skip rotation if file empty |
| `copytruncate` | copy then truncate (use when app holds the FD open and won't reopen) |
| `create MODE OWNER GROUP` | re-create the file with these perms |
| `postrotate ... endscript` | hook (usually `kill -HUP` or `systemctl reload`) |

**Test without rotating**:

```bash
sudo logrotate -d /etc/logrotate.d/myapp     # debug, no action
sudo logrotate -f /etc/logrotate.d/myapp     # force
```

**The classic trap**: an app keeps writing to the old (rotated) file because nobody told it to reopen. Either send SIGHUP in `postrotate`, or use `copytruncate`.

---

## rsyslog vs syslog-ng vs journald

| Aspect | rsyslog | syslog-ng | journald |
|--------|---------|-----------|----------|
| Default on | Debian, RHEL | SUSE, some embedded | every systemd distro |
| Config | `/etc/rsyslog.conf` + `/etc/rsyslog.d/*.conf` | `/etc/syslog-ng/syslog-ng.conf` | `/etc/systemd/journald.conf` |
| Format | RFC 3164 + RFC 5424 + JSON | RFC 3164 + 5424 + structured | binary indexed |
| Destinations | files, TCP, UDP, RELP, kafka, ES, … | files, TCP, UDP, kafka, ES, http, … | local only (forward via syslog or push via fluentd/promtail) |
| Strength | mature, ubiquitous, fast | clean DSL, structured-first | indexed metadata, persistent across boots, native in systemd |
| Weakness | UDP loss, weird config syntax | smaller community | local-only, not for centralized |

**Modern stack**: journald collects, then ships via Promtail/Vector to Loki **or** via rsyslog `imjournal` to a central syslog server.

### Minimal rsyslog forward to remote syslog

`/etc/rsyslog.d/99-forward.conf`:

```text
*.* @@logserver.example.com:514     # @@ = TCP, @ = UDP
```

```bash
sudo systemctl restart rsyslog
logger -t test "hello from $HOSTNAME"
```

---

## Structured logging (JSON) — do this in apps

Plain text:
```text
2026-04-26T10:00:00 INFO User 1234 logged in from 10.0.0.5
```

JSON:
```json
{"ts":"2026-04-26T10:00:00Z","level":"info","msg":"login","user_id":1234,"src_ip":"10.0.0.5","trace_id":"abc123"}
```

JSON wins because:
- `jq` queries: `jq 'select(.user_id == 1234)' app.log`
- Loki / ES auto-index every field
- Grep stays usable: `grep '"trace_id":"abc123"' app.log`
- Logs become metrics: `count by (level) ({app="myapp"} | json | level="error")`

**Convention**: top-level fields `ts`, `level`, `msg`; everything else app-specific. Stick to ISO8601 with `Z`. Never log secrets (auth headers, tokens, PII).

---

## Shipping to Loki (Grafana stack)

### Promtail config — scrape journald + files

`/etc/promtail/config.yml`:

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      path: /var/log/journal
      labels:
        job: systemd-journal
        host: ${HOSTNAME}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal_priority_keyword']
        target_label: 'level'

  - job_name: nginx
    static_configs:
      - targets: [localhost]
        labels:
          job: nginx
          host: ${HOSTNAME}
          __path__: /var/log/nginx/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            status: status
      - labels:
          level:
          status:
```

### LogQL queries

```logql
# All errors for a service in the last hour
{job="systemd-journal", unit="myapp.service"} |~ "(?i)error"

# JSON parse + filter + count
sum by (status) (
  count_over_time({job="nginx"} | json | status >= 500 [5m])
)

# Latency histogram from JSON
quantile_over_time(0.99,
  {job="myapp"} | json | unwrap duration_ms [5m])
```

---

## Shipping to ELK / Opensearch

Filebeat is the classic shipper:

```yaml
# /etc/filebeat/filebeat.yml
filebeat.inputs:
  - type: journald
    id: systemd
    seek: cursor
  - type: filestream
    id: nginx-access
    paths: [/var/log/nginx/access.log]
    parsers:
      - ndjson:
          target: ""
          add_error_key: true

output.elasticsearch:
  hosts: ["https://es:9200"]
  api_key: "${ES_API_KEY}"

processors:
  - add_host_metadata: ~
  - drop_event:
      when:
        regexp:
          message: '^DEBUG'
```

For high volume, use Logstash between Filebeat and Elasticsearch (parse, enrich, queue). For lower complexity, swap Logstash for **Vector** (Rust, faster, simpler config).

---

## Lab: build a log triage workflow

```bash
# 1) Generate noise
for i in {1..1000}; do
  logger -t labapp -p user.info "request id=$i status=200 latency=${RANDOM:0:2}ms"
done
for i in {1..50}; do
  logger -t labapp -p user.err "request id=$i status=500 error=db_timeout"
done

# 2) Find the errors fast
journalctl -t labapp -p err --since "5 min ago" | wc -l
journalctl -t labapp -p err -o json --since "5 min ago" | jq -r .MESSAGE | sort | uniq -c | sort -rn

# 3) Time histogram of all events
journalctl -t labapp --since "5 min ago" -o short-iso | awk '{print substr($1,1,16)}' | sort | uniq -c

# 4) Open in lnav and try its histogram
journalctl -t labapp --since "5 min ago" -o short-iso | lnav
# inside lnav: press 'i' for histogram, ';' for SQL, '/db_timeout' to search
```

### Bonus lab: simulate log rotation

```bash
sudo bash -c 'for i in {1..10000}; do echo "$(date) line $i" >> /tmp/lab.log; done'
sudo tee /etc/logrotate.d/lab >/dev/null <<'EOF'
/tmp/lab.log {
    size 100k
    rotate 5
    compress
    missingok
}
EOF
sudo logrotate -fv /etc/logrotate.d/lab
ls -la /tmp/lab.log*
```

---

!!! tip "20-year tips"
    1. **Persist the journal.** `/var/log/journal` empty by default on Debian — you lose logs across reboot. Fix it on every host.
    2. **Use `-o short-iso` for human-readable ISO8601 timestamps.** The default journalctl format is locale-dependent and useless.
    3. **`journalctl -k`** beats `dmesg` (timestamped, searchable, persistent across reboots).
    4. **JSON logging is non-negotiable for new services.** It's the difference between 10-minute postmortems and 4-hour ones.
    5. **logrotate's `copytruncate` is a footgun for high-throughput logs** (race window where writes are lost). Prefer SIGHUP/reopen-on-rename.
    6. **Loki labels: low cardinality.** Don't put `user_id` or `trace_id` as labels — put them in the line and parse with LogQL. High-cardinality labels destroy Loki.
    7. **Don't log secrets.** Auth headers, tokens, full request bodies — sanitize at the application, not at the shipper.
    8. **Grep before you Kibana.** A 50-line `journalctl | grep` answers most incidents faster than crafting a Lucene query.
    9. **Sample noisy logs at the source.** A debug log producing 100k/sec will saturate Loki/ES and cost you sleep. Drop or sample in Vector/Logstash before shipping.
    10. **Always log the `trace_id`.** With OpenTelemetry traces + log correlation, you go from "user X had an error" to "exact span" in one click.

!!! question "Common interview questions"
    **Q1: How do you find every failure in a systemd unit during a specific 1-hour window?**
    A: `journalctl -u UNIT --since "..." --until "..." -p err` (priorities: emerg=0..debug=7).

    **Q2: rsyslog vs journald — when do you use each?**
    A: journald is the local collector + indexer; mandatory in systemd. rsyslog (or syslog-ng) is for forwarding to a central syslog server or shaping outputs (file, kafka, RELP). Often you use both: journald collects, rsyslog forwards via `imjournal`.

    **Q3: What does `copytruncate` do in logrotate, and what's its risk?**
    A: Copies the log to the rotated name, then truncates the original to zero. Useful when the app keeps the FD open and won't reopen on SIGHUP. Risk: writes between copy and truncate are lost.

    **Q4: Why is JSON logging better than free-text?**
    A: Machine-parseable, every field becomes searchable/aggregatable, both grep and structured query work, easy correlation by IDs (trace_id, request_id, user_id).

    **Q5: How do you avoid high-cardinality label explosions in Loki?**
    A: Keep labels to low-cardinality dimensions (job, host, level, env). Put high-cardinality fields (request_id, user_id) inside the log line and parse with LogQL `| json` at query time.

    **Q6: Difference between Promtail, Filebeat, and Vector?**
    A: Promtail = Loki-native shipper. Filebeat = Elastic-native, lightweight. Vector = generic, multi-output (Loki, ES, Kafka, S3), Rust, often fastest, most flexible config.

    **Q7: How do you persist `journalctl` data across reboots?**
    A: Create `/var/log/journal` (or set `Storage=persistent` in `journald.conf`) and restart `systemd-journald`. Then control retention with `SystemMaxUse=` and `MaxRetentionSec=`.

---

## Sources

- `man journalctl`, `man journald.conf`, `man logrotate`, `man rsyslog.conf`
- [systemd journal documentation](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html)
- [lnav](https://lnav.org/)
- [Grafana Loki](https://grafana.com/oss/loki/), [LogQL](https://grafana.com/docs/loki/latest/query/)
- [Vector](https://vector.dev/)
- [Filebeat](https://www.elastic.co/beats/filebeat)
- [12factor logs](https://12factor.net/logs)
