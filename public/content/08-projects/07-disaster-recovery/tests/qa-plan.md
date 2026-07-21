# QA Plan — Project 07 Disaster Recovery

**Version:** 1.0  
**Owner:** QA Engineer  
**Last updated:** 2026-01-01

---

## Overview

This test plan defines the complete verification suite for the DR infrastructure.
Every test must be executable by an engineer with no prior context beyond this document.
Tests are organized by phase: they can be run independently or as a full regression suite.

**Pass criteria for the DR system (all must pass for a SHIP decision):**

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| RTO | ≤ 900 seconds (15 min) | Wall-clock: failure detection → first healthy HTTP response |
| RPO | ≤ 30 seconds | `now() - pg_last_xact_replay_timestamp()` at failover point |
| Data integrity | SHA-256 match | md5(last 100 rows) before and after failover |
| DNS propagation | ≤ 120 seconds | `dig` loop until secondary IP resolves |
| Traffic error rate | ≤ 1% during failover | k6 `http_req_failed` rate |
| Failback integrity | 0 divergent rows | `SELECT count(*) FROM pg_stat_replication` after sync |

---

## Phase 1 — Pre-conditions

*Verify the DR infrastructure is in a healthy state before any test.*

### P1-01 — Velero backup health

**What:** Confirm Velero is creating successful backups on schedule.

**How:**
```bash
velero backup get --kubeconfig ~/.kube/primary
# Expect: at least one Completed backup in the last 24 hours
# Expect: no backups with phase=Failed in the last 7 days
```

**Pass criteria:**
- [ ] Latest backup phase = `Completed`
- [ ] Latest backup age ≤ 24 hours
- [ ] 0 backups in `Failed` state in the last 7 days
- [ ] Backup is visible on the secondary BSL within 75 seconds of creation

---

### P1-02 — WAL-G archiving health

**What:** Confirm WAL segments are being shipped to S3.

**How:**
```bash
# Check that wal-g backup-list shows a base backup from today
wal-g backup-list DETAIL 2>/dev/null | head -5

# Check WAL segment freshness in S3
aws s3 ls s3://dr-velero-primary-backup/wal-g/prod-postgres/wal_005/ \
  --recursive --human-readable | sort | tail -5
# Most recent segment should be < 15 seconds old
```

**Pass criteria:**
- [ ] Latest base backup completed within 25 hours
- [ ] WAL segments in S3 are < 15 seconds old
- [ ] No `archive_command` failures in Postgres logs (last 1 hour)

---

### P1-03 — S3 replication health

**What:** Confirm cross-region replication is current.

**How:**
```bash
make replication-check
# ReplicationPendingOperations average should be < 10
```

**Pass criteria:**
- [ ] `ReplicationPendingOperations` average ≤ 10 objects
- [ ] No `ReplicationLatency` metric exceeds 900 seconds (15 min)
- [ ] Object uploaded to primary S3 appears in secondary S3 within 60 seconds

---

### P1-04 — Secondary Postgres WAL lag

**What:** Confirm secondary Postgres is following primary with acceptable lag.

**How:**
```bash
make pg-wal-lag
# Expected: replication_lag < 30 seconds
```

**Pass criteria:**
- [ ] WAL replication lag ≤ 30 seconds
- [ ] `pg_is_in_recovery()` returns `t` on secondary
- [ ] No replication errors in Postgres logs (last 1 hour)

---

### P1-05 — Route53 health check status

**What:** Confirm Route53 health checks exist and primary is marked HEALTHY.

**How:**
```bash
aws route53 list-health-checks --query \
  'HealthChecks[*].[Id,HealthCheckConfig.FullyQualifiedDomainName,HealthCheckConfig.Type]' \
  --output table

# Get status of primary health check
aws route53 get-health-check-status --health-check-id <primary-hc-id>
# StatusReport[0].Status should be "Success"
```

**Pass criteria:**
- [ ] Primary health check status = `Success`
- [ ] Secondary health check exists (used during failover)
- [ ] Health check interval = 10 seconds
- [ ] Failure threshold = 3 consecutive failures

---

## Phase 2 — Backup and restore correctness

### P2-01 — Velero restore correctness

**What:** Restore a recent backup to the secondary cluster and verify object counts match.

**How:**
```bash
# Count objects in primary namespace
kubectl --context=primary get all -n production --no-headers | wc -l
# Record this count

# Restore to secondary
make restore

# Count restored objects
kubectl --context=secondary get all -n production --no-headers | wc -l
# Must match primary count (within ±10% for dynamic objects like jobs)
```

**Pass criteria:**
- [ ] Restore phase = `Completed`
- [ ] 0 restore errors
- [ ] Object count in secondary within 10% of primary count
- [ ] All Deployments reach `Available` state within 5 minutes of restore
- [ ] Secrets and ConfigMaps count match exactly

---

### P2-02 — Data integrity after restore

**What:** Verify that the data on secondary Postgres matches primary after WAL replay.

**How:**
```bash
# On primary — capture checksum
PRIMARY_HASH=$(psql -h <primary-pg> -U postgres -Atc "
  SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
  FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;")
echo "Primary hash: ${PRIMARY_HASH}"

# On secondary (after PITR restore)
SECONDARY_HASH=$(psql -h <secondary-pg> -U postgres -Atc "
  SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
  FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;")
echo "Secondary hash: ${SECONDARY_HASH}"

# Compare
[[ "${PRIMARY_HASH}" == "${SECONDARY_HASH}" ]] && echo "PASS: hashes match" || echo "FAIL: data divergence"
```

**Pass criteria:**
- [ ] SHA-256 (md5) of last 100 rows matches between primary and secondary
- [ ] Row count of `orders` table matches between primary and secondary
- [ ] No `NULL` values in fields that should be non-null (schema integrity)

---

### P2-03 — PITR accuracy

**What:** Verify WAL-G PITR restores to the correct point in time.

**How:**
```bash
# Insert a sentinel row on primary with a known timestamp
SENTINEL_TIME=$(psql -h <primary-pg> -U postgres -Atc \
  "INSERT INTO orders(data) VALUES('pitr-test-sentinel') RETURNING created_at;")
echo "Sentinel created at: ${SENTINEL_TIME}"

# Wait 60 seconds
sleep 60

# Insert another row (this should NOT appear after PITR restore to SENTINEL_TIME)
psql -h <primary-pg> -U postgres -c \
  "INSERT INTO orders(data) VALUES('pitr-test-after');"

# Perform PITR restore to SENTINEL_TIME
# (full procedure in REGION_FAILOVER.md Step 6)

# Verify: sentinel row IS present, after row is NOT
psql -h <secondary-pg> -U postgres -c \
  "SELECT * FROM orders WHERE data LIKE 'pitr-test%';"
# Expected: pitr-test-sentinel present, pitr-test-after NOT present
```

**Pass criteria:**
- [ ] Sentinel row present after PITR restore
- [ ] Post-sentinel row absent after PITR restore
- [ ] PITR restore completes within 3 minutes
- [ ] Postgres promotes automatically after reaching recovery target

---

## Phase 3 — DNS failover

### P3-01 — DNS TTL management

**What:** Verify TTL is correctly set and the change propagates.

**How:**
```bash
# Normal TTL
dig api.example.com | grep 'IN A'
# Expected: TTL ~300

# Lower TTL
kubectl annotate svc app-primary \
  external-dns.alpha.kubernetes.io/ttl=60 --overwrite -n production

# Wait 70s (old TTL must expire first)
sleep 70

dig api.example.com | grep 'IN A'
# Expected: TTL ~60
```

**Pass criteria:**
- [ ] TTL changes from 300 → 60 within one TTL cycle
- [ ] ExternalDNS log shows successful Route53 update

---

### P3-02 — Automatic DNS failover

**What:** Simulate primary health check failure and verify Route53 switches to secondary.

**How:**
```bash
# Record current primary IP
PRIMARY_IP=$(dig +short api.example.com @8.8.8.8)
echo "Before: ${PRIMARY_IP}"

# Simulate health check failure
kubectl --context=primary set env deployment/web HEALTH_CHECK_FAIL=true -n production

# Wait for Route53 detection (3 probes × 10s = 30s + buffer)
sleep 45

# Verify DNS switched
CURRENT_IP=$(dig +short api.example.com @8.8.8.8)
echo "After: ${CURRENT_IP}"

SECONDARY_IP=$(kubectl --context=secondary get svc app-secondary -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

[[ "${CURRENT_IP}" == "${SECONDARY_IP}" ]] && echo "PASS: DNS switched to secondary" \
  || echo "FAIL: DNS did not switch"

# Cleanup
kubectl --context=primary set env deployment/web HEALTH_CHECK_FAIL- -n production
```

**Pass criteria:**
- [ ] DNS switches from primary to secondary within 120 seconds of health check failure
- [ ] After cleanup, DNS returns to primary within 1 TTL cycle + propagation time

---

## Phase 4 — Full DR drill

### P4-01 — RTO measurement

**What:** Full failover drill, wall-clock measured.

**How:**
```bash
# Run the full automated drill
make drill

# Or manually follow REGION_FAILOVER.md and measure:
OUTAGE_TIME=$(date +%s)  # T=0: when primary became unresponsive

# After smoke test passes on secondary and DNS propagates:
RECOVERY_TIME=$(date +%s)
RTO=$((RECOVERY_TIME - OUTAGE_TIME))
echo "RTO: ${RTO} seconds"
[[ ${RTO} -le 900 ]] && echo "PASS" || echo "FAIL"
```

**Pass criteria:**
- [ ] RTO ≤ 900 seconds (15 minutes)
- [ ] `make verify-rto-rpo` produces `rto_pass: true`

---

### P4-02 — RPO measurement

**What:** Verify that WAL lag at failover time was within the 30-second target.

**How:**
```bash
# Record at the moment of outage simulation
psql -h <secondary-pg> -U postgres -Atc \
  "SELECT extract(epoch from (now() - pg_last_xact_replay_timestamp()))::int;"
# Must be <= 30
```

**Pass criteria:**
- [ ] RPO ≤ 30 seconds (WAL lag at failover)
- [ ] `make verify-rto-rpo` produces `rpo_pass: true`

---

### P4-03 — Traffic continuity during failover

**What:** Measure HTTP error rate during the failover window using k6.

**How:**
```bash
# Start before the drill, let run through failover
k6 run tests/k6/during-drill.js \
  --env BASE_URL=https://api.example.com \
  --duration 20m \
  --vus 20 \
  --out json=/tmp/k6-drill-result.json

# After drill, analyze error rate during the failover window
# The test emits metrics tagged with drill phases
```

**Pass criteria:**
- [ ] `http_req_failed` rate ≤ 1% during the failover window (T+0 to T+15m)
- [ ] p95 latency ≤ 250ms after failover stabilizes (T+15m to end)
- [ ] 0 test assertions failed

---

### P4-04 — Failback integrity

**What:** Verify no data divergence after failback to primary.

**How:**
```bash
# After failback, compare row counts in both regions
PRIMARY_COUNT=$(psql -h <primary-pg> -U postgres -Atc "SELECT count(*) FROM orders;")
SECONDARY_COUNT=$(psql -h <secondary-pg> -U postgres -Atc "SELECT count(*) FROM orders;")
echo "Primary: ${PRIMARY_COUNT} rows"
echo "Secondary: ${SECONDARY_COUNT} rows"

[[ "${PRIMARY_COUNT}" == "${SECONDARY_COUNT}" ]] \
  && echo "PASS: row counts match" \
  || echo "FAIL: divergence detected (primary: ${PRIMARY_COUNT}, secondary: ${SECONDARY_COUNT})"
```

**Pass criteria:**
- [ ] Row count identical between primary and secondary after failback
- [ ] `pg_stat_replication` shows 0 replication lag after sync
- [ ] DNS confirmed on primary by all three resolvers (8.8.8.8, 1.1.1.1, 9.9.9.9)

---

## Phase 5 — Negative testing

### P5-01 — Backup failure detection

**What:** Verify that a failed Velero backup triggers an alert.

**How:**
```bash
# Temporarily revoke S3 permissions to force a backup failure
# (lab environment only — never in production)
# Then trigger a backup and verify the failure is detected

velero backup create failure-test-$(date +%s) \
  --include-namespaces production --wait
velero backup get | grep failure-test
# Should show phase=Failed

# Verify CloudWatch alarm fires
aws cloudwatch describe-alarms \
  --alarm-name-prefix velero-backup \
  --query 'MetricAlarms[*].[AlarmName,StateValue]'
```

**Pass criteria:**
- [ ] Failed backup triggers CloudWatch alarm within 5 minutes
- [ ] PagerDuty alert fires (check test PD routing rules)

---

### P5-02 — WAL archiving failure detection

**What:** Verify WAL archiving failures are detected and alerted.

**How:**
```bash
# Check Postgres logs for archive_command failures
kubectl --context=primary logs -n production \
  -l app=postgres,role=primary --since=1h | grep "archive command failed"

# Verify the monitoring alert exists
aws cloudwatch describe-alarms \
  --alarm-name-prefix wal-archive \
  --query 'MetricAlarms[*].[AlarmName,StateValue]'
```

**Pass criteria:**
- [ ] Archive failures appear in structured logs within 30 seconds
- [ ] 3+ consecutive failures trigger a CloudWatch alarm

---

## Test execution matrix

| Test ID | Manual | Automated | Frequency | Last run | Result |
|---------|--------|-----------|-----------|----------|--------|
| P1-01 | | ✓ | Daily (CI) | | |
| P1-02 | | ✓ | Daily (CI) | | |
| P1-03 | | ✓ | Hourly | | |
| P1-04 | | ✓ | Every 5 min | | |
| P1-05 | | ✓ | Every 5 min | | |
| P2-01 | | ✓ | Weekly | | |
| P2-02 | ✓ | | Monthly | | |
| P2-03 | ✓ | | Monthly | | |
| P3-01 | | ✓ | Weekly | | |
| P3-02 | ✓ | | Monthly | | |
| P4-01 | ✓ | ✓ | Quarterly | | |
| P4-02 | ✓ | ✓ | Quarterly | | |
| P4-03 | ✓ | ✓ | Quarterly | | |
| P4-04 | ✓ | ✓ | Quarterly | | |
| P5-01 | ✓ | | Quarterly | | |
| P5-02 | ✓ | | Quarterly | | |

---

## Pass/Fail decision

**PASS (ship):** All Phase 1–4 tests pass. Phase 5 negative tests have corresponding alerts.

**CONDITIONAL PASS:** Phase 1–3 pass. Phase 4 RTO exceeded by < 10% with a documented action item for automation improvement.

**FAIL (do not ship):** Any of:
- RTO > 990 seconds (110% of target)
- RPO > 30 seconds
- Data integrity check fails
- DNS failover takes > 3 minutes
- Failback produces divergent row counts
