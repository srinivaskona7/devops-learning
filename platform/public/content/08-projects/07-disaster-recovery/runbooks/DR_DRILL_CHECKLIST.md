# DR Drill Checklist — Quarterly Exercise

**Version:** 2026-01-01  
**Cadence:** Once per quarter (January, April, July, October)  
**Duration:** 3–4 hours including setup, drill, verification, and debrief  
**Owner:** SRE team  
**Observers required:** Engineering lead, product manager (SLA accountability)

---

## Purpose

This checklist converts the DR runbook from documentation into muscle memory.
A drill that is interrupted, skipped, or only partially completed provides less
value than no drill at all — it creates false confidence.

**Rule:** Every drill must produce a machine-readable pass/fail JSON report (`make verify-rto-rpo`).
If the drill produces no report, it did not happen.

---

## Pre-drill: T-7 days (one week before)

### Infrastructure verification

- [ ] Confirm S3 CRR is healthy: `aws s3api get-bucket-replication --bucket dr-velero-primary-backup`
- [ ] Confirm Velero backups are running: `velero backup get | grep Completed | head -5`
- [ ] Confirm WAL-G is archiving: check `wal-g backup-list` shows a backup from the last 24 hours
- [ ] Confirm secondary cluster is healthy: `kubectl --context=secondary get nodes`
- [ ] Confirm secondary Postgres standby is running: `psql -h <secondary-pg> -c "SELECT pg_is_in_recovery();"`
- [ ] Check replication lag is < 30s: `psql -h <secondary-pg> -c "SELECT now() - pg_last_xact_replay_timestamp();"`
- [ ] Confirm ExternalDNS is running on secondary: `kubectl --context=secondary get deploy external-dns -n kube-system`
- [ ] Verify Route53 health checks exist for both primary and secondary records

### Communication preparation

- [ ] Notify stakeholders of drill window (date, time, expected duration)
- [ ] Create draft status page update (DO NOT post until drill starts)
- [ ] Confirm war room channel is available (Slack or Zoom)
- [ ] Ensure all participants have AWS Console + kubectl access
- [ ] Assign roles: incident commander, scribe, ops engineer, observer

### Baseline measurements

Record these BEFORE the drill for comparison:

```bash
# 1. Current WAL lag
psql -h <secondary-pg> -U postgres -c "
  SELECT now() - pg_last_xact_replay_timestamp() AS baseline_replication_lag;"

# 2. Last Velero backup time
velero backup get -o json | jq -r \
  '[.items[] | select(.status.phase=="Completed")] |
   sort_by(.metadata.creationTimestamp) | last |
   {name:.metadata.name, created:.metadata.creationTimestamp}'

# 3. SHA-256 of reference dataset
psql -h <primary-pg> -U postgres -c "
  SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
  FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;" \
  > /tmp/pre-drill-checksum.txt
cat /tmp/pre-drill-checksum.txt

# 4. Current DNS resolution
dig +short api.example.com @8.8.8.8
dig +short api.example.com @1.1.1.1
```

---

## Pre-drill: T-30 minutes (30 minutes before)

- [ ] Lower DNS TTL to 60s:
  ```bash
  kubectl annotate svc app-primary \
    external-dns.alpha.kubernetes.io/ttl=60 --overwrite -n production
  ```
- [ ] Verify TTL change propagated:
  ```bash
  dig api.example.com | grep ttl
  ```
- [ ] Start k6 continuous traffic test (keep running throughout drill):
  ```bash
  # In a separate terminal — do not kill this until after failback
  k6 run tests/k6/during-drill.js --out json=/tmp/k6-drill-$(date +%s).json
  ```
- [ ] Confirm k6 is generating traffic (check output shows requests flowing)
- [ ] Open CloudWatch dashboard for primary cluster (leave open for visual monitoring)
- [ ] Mark drill start time: `DRILL_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)`

---

## Phase 1 — Simulate outage (T+0:00)

**Goal:** Create a realistic region failure without actually losing the primary region.

- [ ] Label primary nodes as unschedulable:
  ```bash
  # This prevents new pods from starting on primary (simulates region loss for K8s)
  kubectl --context=primary get nodes -o name | xargs -I{} \
    kubectl --context=primary taint {} disaster-recovery/drill=active:NoSchedule
  ```
- [ ] Block S3 access from primary cluster (simulate S3 regional outage):
  ```bash
  # Apply a NetworkPolicy that denies egress to S3 endpoints
  kubectl --context=primary apply -f - <<'EOF'
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: block-s3-drill
    namespace: production
  spec:
    podSelector: {}
    policyTypes: [Egress]
    egress:
      - to:
          - ipBlock:
              cidr: 0.0.0.0/0
              except:
                - 52.216.0.0/14    # S3 us-east-1 range (approximate)
  EOF
  ```
- [ ] Simulate health check failure on primary (make /healthz return 503):
  ```bash
  kubectl --context=primary set env deployment/web \
    HEALTH_CHECK_FAIL=true -n production
  ```
- [ ] Record simulated outage start time: `OUTAGE_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)`

**Verify simulation is working:**
- [ ] Route53 health check shows PRIMARY as UNHEALTHY (check AWS Console or `aws route53 get-health-check-status`)
- [ ] k6 is showing increased error rate (expected: errors spike as some traffic hits dead primary)

---

## Phase 2 — Execute failover (following REGION_FAILOVER.md)

Complete ALL 15 steps from `REGION_FAILOVER.md`. Check each step as it completes:

- [ ] Step 1 — Declare incident (create PagerDuty test incident for drill)
- [ ] Step 2 — Confirm region loss (verify via kubectl timeout + health check)
- [ ] Step 3 — Measure WAL lag
  - **Record:** WAL lag at outage = _______ seconds
  - **Gate:** Must be ≤ 30s to proceed without approval
- [ ] Step 4 — Lower DNS TTL (already done in T-30 min prep, verify)
- [ ] Step 5 — Start Velero restore
  - **Record:** Restore started at = _______
- [ ] Step 6 — Promote Postgres standby
  - **Record:** Postgres promoted at = _______
- [ ] Step 7 — Update application connection string
- [ ] Step 8 — Verify Velero restore completed
  - **Record:** Restore completed at = _______
  - **Gate:** Phase=Completed, 0 errors
- [ ] Step 9 — Smoke test on secondary
  - [ ] /healthz = 200
  - [ ] /api/health/db = 200 (role=primary)
  - [ ] Sample data read = 200
- [ ] Step 10 — DNS cutover
  - **Record:** DNS cutover at = _______
- [ ] Step 11 — Monitor error rate during propagation
  - **Record:** Error rate peak = _______% at _______
  - **Record:** Error rate normalized at = _______
- [ ] Step 12 — Verify RTO
  - **Record:** RTO = _______ minutes

---

## Phase 3 — Verification (T+15:00 or when service is restored)

### RTO verification

```bash
DRILL_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Drill start:     ${DRILL_START}"
echo "Outage start:    ${OUTAGE_START}"
echo "Service restored: ${DRILL_END}"
# Calculate RTO = DRILL_END - OUTAGE_START
```

- [ ] RTO ≤ 900 seconds (15 minutes): **PASS / FAIL** — _______
- [ ] If FAIL: document why and create action item for automation improvement

### RPO verification

```bash
# Get the SHA-256 of the same 100 rows on the secondary Postgres
psql -h <secondary-pg> -U postgres -c "
  SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
  FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;" \
  > /tmp/post-drill-checksum.txt

# Compare checksums
diff /tmp/pre-drill-checksum.txt /tmp/post-drill-checksum.txt
# Expected: no diff (checksums match)
```

- [ ] Data integrity check (SHA-256 match): **PASS / FAIL** — _______
- [ ] WAL lag at failover ≤ 30 seconds: **PASS / FAIL** — _______

### DNS verification

```bash
# Verify DNS is now pointing to secondary
dig +short api.example.com @8.8.8.8
dig +short api.example.com @1.1.1.1
dig +short api.example.com @9.9.9.9
# All should return secondary ALB IP
```

- [ ] All DNS resolvers return secondary IP: **PASS / FAIL** — _______
- [ ] DNS propagation time ≤ 90 seconds: **PASS / FAIL** — _______

### Traffic verification

```bash
# Review k6 summary
# Kill k6 ONLY after recording metrics, or let it run until failback
cat /tmp/k6-drill-*.json | jq '.metrics.http_req_failed | .thresholds'
```

- [ ] k6 error rate during failover window ≤ 1%: **PASS / FAIL** — _______
- [ ] k6 p95 latency post-failover ≤ 250ms: **PASS / FAIL** — _______

### Machine-readable report

```bash
make verify-rto-rpo
# Review the JSON output
cat /tmp/dr-drill-report-*.json | jq .
```

- [ ] JSON report generated: **YES / NO**
- [ ] `rto_pass: true`: **YES / NO**
- [ ] `rpo_pass: true`: **YES / NO**
- [ ] `data_integrity_sha256: "match"`: **YES / NO**

---

## Phase 4 — Failback (T+30:00)

After 15 minutes of stable secondary operation, execute failback.

- [ ] Restore simulation (remove taints and NetworkPolicy from primary):
  ```bash
  kubectl --context=primary get nodes -o name | xargs -I{} \
    kubectl --context=primary taint {} disaster-recovery/drill:NoSchedule-

  kubectl --context=primary delete networkpolicy block-s3-drill -n production

  kubectl --context=primary set env deployment/web \
    HEALTH_CHECK_FAIL- -n production  # remove the env var
  ```
- [ ] Verify primary cluster and Postgres are healthy
- [ ] Resync Postgres (secondary → primary):
  ```bash
  # Take a base backup on secondary and restore to primary
  # This ensures primary has all writes that occurred during DR
  wal-g backup-push ${PGDATA} --context=secondary
  # Then restore to primary and replay WAL
  ```
- [ ] Run smoke test on primary:
  ```bash
  curl -sf https://<primary-alb>/healthz | jq .
  curl -sf https://<primary-alb>/api/health/db | jq .
  ```
- [ ] Execute DNS failback:
  ```bash
  kubectl annotate svc app-secondary \
    external-dns.alpha.kubernetes.io/aws-weight=0 --overwrite -n production
  kubectl annotate svc app-primary \
    external-dns.alpha.kubernetes.io/aws-weight=100 --overwrite -n production
  ```
- [ ] Reset TTL to 300s:
  ```bash
  kubectl annotate svc app-primary \
    external-dns.alpha.kubernetes.io/ttl=300 --overwrite -n production
  ```
- [ ] Verify DNS back on primary:
  ```bash
  dig +short api.example.com @8.8.8.8
  # Should return primary ALB IP
  ```
- [ ] Stop k6 test and save report
- [ ] Mark drill complete: `DRILL_COMPLETE=$(date -u +%Y-%m-%dT%H:%M:%SZ)`

---

## Phase 5 — Debrief (T+90:00)

Run the debrief immediately after the drill (same day).

### Debrief agenda (30 minutes)

| Time | Topic |
|------|-------|
| 0–5 min | Review pass/fail metrics from JSON report |
| 5–15 min | What surprised us? What was harder than expected? |
| 15–20 min | What should we automate that was manual? |
| 20–25 min | What should we test next quarter that we did not test today? |
| 25–30 min | Assign action items (owner + due date) |

### Debrief checklist

- [ ] Actual RTO: _______ minutes (target: ≤ 15 min)
- [ ] Actual RPO: _______ seconds (target: ≤ 30 s)
- [ ] Steps that took longer than expected: _______
- [ ] Steps that required deviating from the runbook: _______
- [ ] New failure modes discovered: _______
- [ ] Action items created: _______ (min 2, max 10)
- [ ] Runbook updates needed: _______
- [ ] Postmortem scheduled: YES / NO (schedule even for PASS drills)

---

## Drill results log

*Append to this table after every drill.*

| Date | RTO (min) | RPO (s) | Data match | DNS (s) | k6 error % | Overall | Lead |
|------|-----------|---------|-----------|---------|-----------|---------|------|
| 2026-Q1 | | | | | | | |
| 2026-Q2 | | | | | | | |
| 2026-Q3 | | | | | | | |
| 2026-Q4 | | | | | | | |

**Trend analysis:** RTO and RPO should improve each quarter as automation increases.
If they worsen, the system is degrading — escalate to engineering leadership.

---

## Known drill issues and workarounds

*Document issues discovered in previous drills here so future drills avoid them.*

| Issue | Discovered | Workaround | Permanent fix |
|-------|-----------|------------|---------------|
| [example] ExternalDNS propagation takes 2x expected time | 2026-Q1 | Lower TTL 1h before drill | Set TTL=60 permanently |

---

*Template version: 2026-01-01. Owner: SRE team.*
