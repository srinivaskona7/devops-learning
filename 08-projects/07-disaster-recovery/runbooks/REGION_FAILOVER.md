# REGION FAILOVER RUNBOOK

**Classification:** Tier 1 Incident Response  
**Owner:** On-Call SRE  
**Effective:** 2026-01-01  
**Review cadence:** Quarterly (after every DR drill)

---

## When to use this runbook

Use this runbook when **all** of the following are true:

- [ ] Route53 health check for primary region is **RED** for > 5 minutes
- [ ] Direct connectivity to primary cluster returns timeouts or connection refused
- [ ] CloudWatch alarm `region-primary-loss` has fired
- [ ] You have confirmed this is NOT a network blip (check AWS Service Health Dashboard)

**Do NOT use this runbook for:**
- Single AZ failure (multi-AZ K8s handles this transparently)
- Application crashes (use the application restart runbook)
- Database failover within a region (use the Postgres failover runbook)

---

## Pre-failover checklist (complete BEFORE starting steps)

| # | Check | How | Required |
|---|-------|-----|---------|
| 1 | AWS Service Health Dashboard | https://health.aws.amazon.com | Yes |
| 2 | PagerDuty incident created and acknowledged | PagerDuty UI | Yes |
| 3 | Secondary cluster kubectl context available | `kubectl --context=secondary get nodes` | Yes |
| 4 | WAL-G S3 replication lag measured | Step 3 | Yes |
| 5 | Stakeholder notification sent | Slack #incidents | Yes |
| 6 | War room opened | Slack huddle or Zoom | Recommended |

---

## Decision tree

```text
Primary region unresponsive?
  ├─ YES for < 5 min → Wait. Transient network issues are common.
  ├─ YES for 5-10 min → Escalate, prepare failover, do NOT execute yet.
  └─ YES for > 10 min → Execute this runbook.

Is this a planned drill?
  ├─ YES → Follow DR_DRILL_CHECKLIST.md instead (has rollback gate at each step)
  └─ NO  → Continue with steps below
```

---

## STEP 1 — Declare incident (T+0:00)

Declare the incident in PagerDuty and create a Slack incident channel.

```bash
# Acknowledge PagerDuty alert (prevents re-paging)
# Use PagerDuty mobile app or web interface

# Open incident channel
# Slack: /incident declare "Primary region us-east-1 unresponsive"
# Post to #incidents and #engineering-leadership

echo "INCIDENT DECLARED at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Incident ID: INC-$(date +%Y%m%d-%H%M%S)"
```

**Record:** Incident start time (T=0).  
**Duration budget consumed:** 0 min / 15 min

---

## STEP 2 — Confirm region loss (T+0:30)

Distinguish between a region-level outage (act) and an application failure (different runbook).

```bash
# Test 1: Can we reach the primary cluster API server?
kubectl --context=primary get nodes --request-timeout=10s
# Expected on region loss: connection timeout or refused

# Test 2: Is AWS reporting the region as degraded?
aws health describe-events \
  --filter eventStatusCodes=open \
  --region us-east-1 \
  --query 'events[?region==`us-east-1`].[eventTypeCode,statusCode,lastUpdatedTime]' \
  --output table

# Test 3: Can we reach the primary S3 bucket from the secondary region?
aws s3 ls s3://dr-velero-primary-backup --region us-east-1
# If this times out but secondary bucket is reachable → region loss confirmed

# Test 4: Route53 health check status
aws route53 get-health-check-status \
  --health-check-id $(aws route53 list-health-checks \
    --query 'HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName==`api.example.com`].Id' \
    --output text)
```

**Decision gate:**
- If primary cluster responds → **STOP**. This is NOT a region-level outage. Use application restart runbook.
- If primary region unresponsive → proceed to Step 3.

**Duration budget consumed:** ~1 min / 15 min

---

## STEP 3 — Measure WAL lag and estimate RPO (T+1:00)

Before failing over, calculate how much data loss to expect. This number goes into the incident report.

```bash
# Connect to Postgres standby in the SECONDARY region
SECONDARY_PG_HOST=$(kubectl --context=secondary \
  get svc postgres-secondary -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check WAL replay lag
psql -h "${SECONDARY_PG_HOST}" -U postgres -c "
SELECT
  now()                              AS current_time,
  pg_last_xact_replay_timestamp()    AS last_replayed,
  now() - pg_last_xact_replay_timestamp() AS replication_lag,
  CASE
    WHEN now() - pg_last_xact_replay_timestamp() <= interval '30 seconds'
    THEN 'RPO WITHIN TARGET (≤30s)'
    ELSE 'RPO BREACH — data loss possible'
  END AS rpo_status
;"
```

**Record:** WAL lag value in incident notes.

```bash
# Also check the latest WAL-G base backup timestamp
wal-g backup-list DETAIL 2>/dev/null | head -5
# Look for: last_modified, WAL_segment_backup_start
```

**Decision gate:**
- WAL lag ≤ 30 s → proceed. RPO target met.
- WAL lag 30–120 s → proceed with approval from engineering lead. Document expected data loss.
- WAL lag > 120 s → escalate to engineering lead before proceeding. Consider if failover is worth the data loss.

**Duration budget consumed:** ~1.5 min / 15 min

---

## STEP 4 — Lower DNS TTL (T+1:30)

Reduce TTL so client DNS caches expire faster after the failover record update.

```bash
# Lower TTL to 60s on both records
kubectl --context=secondary annotate svc app-secondary \
  external-dns.alpha.kubernetes.io/ttl=60 \
  --overwrite -n production

kubectl --context=secondary annotate svc app-primary \
  external-dns.alpha.kubernetes.io/ttl=60 \
  --overwrite -n production

echo "TTL lowered to 60s at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "DNS propagation will complete in ~90s for most clients"
```

**Note:** If you cannot reach the primary cluster (region loss), only annotate the secondary service. ExternalDNS on the secondary cluster will propagate the change.

**Duration budget consumed:** ~2 min / 15 min

---

## STEP 5 — Start Velero restore on secondary cluster (T+2:00)

Restore K8s application state (Deployments, Services, ConfigMaps, Secrets, PVCs) from the replicated backup.

```bash
# Switch context to secondary cluster
kubectl config use-context secondary

# List available backups (replicated from primary via S3 CRR)
velero backup get --namespace velero
# Look for: most recent backup with phase=Completed

# Get the name of the most recent completed backup
LATEST_BACKUP=$(velero backup get -o json \
  | jq -r '[.items[]
     | select(.status.phase == "Completed")
     | select(.metadata.labels["dr.example.com/schedule"] == "daily-full")
    ] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')

echo "Restoring from backup: ${LATEST_BACKUP}"

# Create the restore
velero restore create dr-restore-$(date +%s) \
  --from-backup "${LATEST_BACKUP}" \
  --include-namespaces production \
  --existing-resource-policy update \
  --wait
```

**Watch progress:**

```bash
# Follow restore progress in another terminal
watch -n 5 'velero restore describe $(velero restore get -o json \
  | jq -r "[.items[]] | sort_by(.metadata.creationTimestamp) | last | .metadata.name") \
  --details 2>/dev/null | tail -30'
```

**Duration budget consumed:** ~8 min / 15 min (restore takes ~6 min)

---

## STEP 6 — Promote Postgres standby to primary (T+4:00)

The WAL-G standby in the secondary region has been replaying WAL. Promote it to accept writes.

```bash
# Connect to secondary postgres
SECONDARY_PG_POD=$(kubectl --context=secondary \
  get pod -n production -l app=postgres,role=standby \
  -o jsonpath='{.items[0].metadata.name}')

# Check current state (should show 'in recovery')
kubectl --context=secondary exec -n production "${SECONDARY_PG_POD}" \
  -- psql -U postgres -c "SELECT pg_is_in_recovery();"
# Expected: t (true = standby mode)

# Perform PITR to the last known safe timestamp
# Use the incident timestamp minus 60s as recovery target
RECOVERY_TARGET=$(date -u -d "-90 seconds" +"%Y-%m-%d %H:%M:%S+00" 2>/dev/null \
  || date -u -v-90S +"%Y-%m-%d %H:%M:%S+00")  # macOS

kubectl --context=secondary exec -n production "${SECONDARY_PG_POD}" \
  -- psql -U postgres -c "
    SELECT pg_promote(wait := true, wait_seconds := 60);
  "
# If pg_promote is unavailable (PG < 12): touch /tmp/promote.signal

# Verify promotion
kubectl --context=secondary exec -n production "${SECONDARY_PG_POD}" \
  -- psql -U postgres -c "SELECT pg_is_in_recovery();"
# Expected: f (false = primary mode)

echo "Postgres promoted to primary at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Duration budget consumed:** ~5 min / 15 min

---

## STEP 7 — Update application database connection string (T+5:30)

Point applications in the secondary cluster at the newly promoted Postgres primary.

```bash
# Update the database ConfigMap with secondary Postgres endpoint
SECONDARY_PG_HOST=$(kubectl --context=secondary \
  get svc postgres-secondary -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

kubectl --context=secondary patch configmap app-config -n production \
  --type merge \
  -p "{\"data\": {\"DATABASE_HOST\": \"${SECONDARY_PG_HOST}\", \"DATABASE_ROLE\": \"primary\"}}"

# Roll out the application to pick up new config
kubectl --context=secondary rollout restart deployment/web -n production
kubectl --context=secondary rollout status deployment/web -n production --timeout=120s
```

**Duration budget consumed:** ~7 min / 15 min

---

## STEP 8 — Verify Velero restore completed (T+7:00)

Confirm the restore from Step 5 has completed before proceeding.

```bash
RESTORE_NAME=$(velero restore get -o json \
  | jq -r '[.items[]] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')

velero restore describe "${RESTORE_NAME}" | grep -E "Phase:|Errors:|Warnings:"
# Expected: Phase: Completed
# Warnings are acceptable; Errors are not

# Verify critical workloads are running
kubectl --context=secondary get pods -n production
# Expected: all pods Running or Completed
```

**Decision gate:**
- Phase=Completed, 0 errors → proceed.
- Phase=Failed or errors > 0 → see debugging steps in [`POST_INCIDENT.md`](./POST_INCIDENT.md).

**Duration budget consumed:** ~8 min / 15 min

---

## STEP 9 — Run smoke test on secondary (T+8:00)

Verify the application in the secondary region responds correctly before cutting DNS.

```bash
SECONDARY_ALB=$(kubectl --context=secondary \
  get svc app-secondary -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl -sf --connect-timeout 5 \
  "https://${SECONDARY_ALB}/healthz" | jq .
# Expected: {"status":"ok","region":"us-west-2"}

# Database connectivity check
curl -sf --connect-timeout 5 \
  "https://${SECONDARY_ALB}/api/health/db" | jq .
# Expected: {"database":"connected","replication_lag_seconds":null,"role":"primary"}

# Sample data read (verify WAL replay completed correctly)
curl -sf --connect-timeout 5 \
  "https://${SECONDARY_ALB}/api/users?limit=1" | jq .
# Expected: 200 OK with user data
```

**Decision gate:**
- All three checks return 200 OK → proceed to DNS cutover.
- Any check fails → debug before cutting DNS (do not send traffic to a broken secondary).

**Duration budget consumed:** ~9 min / 15 min

---

## STEP 10 — Execute DNS cutover (T+9:00)

Activate the secondary Route53 record. Traffic will migrate as DNS TTLs expire.

```bash
# Activate secondary record (weight=100)
kubectl --context=secondary annotate svc app-secondary \
  external-dns.alpha.kubernetes.io/aws-weight=100 \
  --overwrite -n production

echo "DNS cutover initiated at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Propagation expected within 90s (TTL=60s)"

# Monitor DNS propagation
# Run this loop until the secondary IP consistently resolves
SECONDARY_IP=$(kubectl --context=secondary \
  get svc app-secondary -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

for i in $(seq 1 12); do
  RESOLVED=$(dig +short api.example.com @8.8.8.8 | head -1)
  echo "$(date -u +%H:%M:%S) dig result: ${RESOLVED} (target: ${SECONDARY_IP})"
  [[ "${RESOLVED}" == "${SECONDARY_IP}" ]] && echo "DNS propagated!" && break
  sleep 10
done
```

**Duration budget consumed:** ~10 min / 15 min

---

## STEP 11 — Monitor error rate during DNS propagation (T+10:00)

DNS clients do not flush simultaneously. For ~90 seconds, some clients still hit the dead primary. Monitor error rate.

```bash
# Watch k6 output (if continuous traffic test is running from tests/drill.sh)
# The error rate should peak during propagation then return to ~0%

# Alternative: check ALB access logs in real time
aws logs tail /aws/alb/app-secondary \
  --follow \
  --format short \
  --filter-pattern '{ $.status >= 400 }' \
  --region us-west-2

# Expected: error spike from DNS propagation, then drops to ~0 within 2 min
```

**Decision gate:**
- Error rate < 1% after 90 seconds → DNS propagation complete, proceed.
- Error rate > 5% after 3 minutes → check secondary application health. May need to roll back DNS.

**Duration budget consumed:** ~12 min / 15 min

---

## STEP 12 — Verify RTO target met (T+12:00)

```bash
# Record actual RTO
INCIDENT_START="<T=0 timestamp from Step 1>"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Incident start: ${INCIDENT_START}"
echo "Service restored: ${NOW}"

# Run automated RTO/RPO verification
make verify-rto-rpo
# This outputs a JSON report with actual measured values
```

**Record:** Actual RTO and RPO values in incident notes.

**Duration budget consumed:** ~13 min / 15 min

---

## STEP 13 — Notify stakeholders (T+13:00)

```text
STATUS: Service restored in secondary region (us-west-2)
Primary region: us-east-1 — OFFLINE (AWS incident in progress)
Secondary region: us-west-2 — SERVING TRAFFIC
RTO achieved: [X minutes]
RPO: [Y seconds] data loss
Next steps: Monitor for 30 minutes, then assess failback timeline
Postmortem: Scheduled for [48h from now]
```

Post to: `#incidents`, `#status-page`, engineering leadership.

---

## STEP 14 — Monitor secondary for 30 minutes (T+13:30)

```bash
# Watch key metrics on secondary cluster
watch -n 30 "
  echo '=== Pod health ==='
  kubectl --context=secondary get pods -n production --no-headers | grep -v Running

  echo '=== Error rate (last 5m) ==='
  aws cloudwatch get-metric-statistics \
    --namespace ApplicationMetrics \
    --metric-name HTTPErrors \
    --start-time $(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-5M +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 --statistics Sum \
    --region us-west-2 \
    --query 'Datapoints[0].Sum'

  echo '=== Postgres writes ==='
  psql -h \${SECONDARY_PG_HOST} -U postgres -c 'SELECT count(*) FROM pg_stat_activity WHERE state='''active'''';'
"
```

---

## STEP 15 — Initiate failback assessment (T+43:00)

After 30 minutes of stable secondary operation, assess when to failback.

**Failback criteria — all must be true:**

- [ ] Primary region AWS incident is resolved (Service Health Dashboard green)
- [ ] Primary cluster can be reached via kubectl
- [ ] Primary Postgres can be started and synced with secondary writes
- [ ] All data written to secondary Postgres is replicated back to primary
- [ ] Stakeholder approval for maintenance window

If all criteria met → proceed with [`DR_DRILL_CHECKLIST.md`](./DR_DRILL_CHECKLIST.md) failback section.  
If criteria not met → remain on secondary. Schedule reassessment in 2 hours.

```bash
# When ready to failback, lower TTL again first
kubectl --context=primary annotate svc app-primary \
  external-dns.alpha.kubernetes.io/ttl=60 \
  --overwrite -n production

make failback
```

---

## Rollback (abort failover mid-execution)

If at any point before Step 10 (DNS cutover) you need to abort:

```bash
# Cancel Velero restore
velero restore delete dr-restore-* --confirm

# Demote Postgres back to standby (if promoted in Step 6)
# This requires a full re-sync from primary — only do this if primary is reachable
# psql -h <secondary_pg> -c "SELECT pg_ctl_status();"

# Reset TTL to 300
kubectl --context=secondary annotate svc app-secondary \
  external-dns.alpha.kubernetes.io/ttl=300 \
  --overwrite -n production

echo "Failover aborted. Primary region assumed to have recovered."
```

After Step 10, rollback requires a second DNS cutover back to primary. This takes another ~90 seconds of propagation time.

---

## Contact escalation matrix

| Escalation level | Contact | When |
|-----------------|---------|------|
| L1: On-call SRE | PagerDuty on-call | Immediately on alarm |
| L2: SRE lead | Slack DM + phone | Step 3 WAL lag > 120s |
| L3: Engineering director | Phone | RTO > 15 min or data loss confirmed |
| L4: CTO + external comms | Phone + email | Customer-facing outage > 30 min |
| AWS support | Business/Enterprise support case | AWS infrastructure incident |
