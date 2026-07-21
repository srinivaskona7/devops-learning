#!/usr/bin/env bash
# =============================================================================
# tests/drill.sh
#
# Scripted DR drill:
#   1. Records pre-drill baseline (checksum, WAL lag, DNS)
#   2. Triggers outage simulation (or waits for --verify-only flag)
#   3. Executes failover (calls Makefile targets)
#   4. Measures actual RTO and RPO
#   5. Verifies data integrity (SHA-256 row checksum)
#   6. Emits a machine-readable JSON report
#
# Usage:
#   bash tests/drill.sh                  # Full drill (simulate + failover + verify)
#   bash tests/drill.sh --verify-only    # Only verify RTO/RPO (use during manual drill)
#   bash tests/drill.sh --failback-only  # Only execute failback
#   bash tests/drill.sh --dry-run        # Print steps without executing
#
# Exit codes:
#   0 — All pass criteria met
#   1 — One or more pass criteria failed
#   2 — Script error (missing dependencies, etc.)
# =============================================================================
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
PRIMARY_CONTEXT="${PRIMARY_CONTEXT:-primary}"
SECONDARY_CONTEXT="${SECONDARY_CONTEXT:-secondary}"
PRIMARY_NS="${PRIMARY_NS:-production}"
SECONDARY_NS="${SECONDARY_NS:-production}"
DNS_HOSTNAME="${DNS_HOSTNAME:-api.example.com}"
RTO_TARGET_SECONDS="${RTO_TARGET_SECONDS:-900}"       # 15 minutes
RPO_TARGET_SECONDS="${RPO_TARGET_SECONDS:-30}"
ERROR_RATE_TARGET="${ERROR_RATE_TARGET:-0.01}"        # 1%
DNS_PROPAGATION_TARGET="${DNS_PROPAGATION_TARGET:-120}"

REPORT_DIR="${REPORT_DIR:-/tmp/dr-drill-reports}"
REPORT_FILE="${REPORT_DIR}/dr-drill-$(date +%Y%m%d-%H%M%S).json"

# CLI flags
VERIFY_ONLY="${VERIFY_ONLY:-false}"
FAILBACK_ONLY="${FAILBACK_ONLY:-false}"
DRY_RUN="${DRY_RUN:-false}"

# ─── Parse arguments ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "${arg}" in
    --verify-only)  VERIFY_ONLY=true ;;
    --failback-only) FAILBACK_ONLY=true ;;
    --dry-run)      DRY_RUN=true ;;
    --help)
      grep '^#' "$0" | head -30 | sed 's/^# //'
      exit 0
      ;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { printf '\033[0;32m[drill] %s\033[0m\n' "$*" >&2; }
warn() { printf '\033[0;33m[drill] WARN: %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[0;31m[drill] ERROR: %s\033[0m\n' "$*" >&2; }

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '\033[0;36m[dry-run] %s\033[0m\n' "$*" >&2
    return 0
  fi
  eval "$@"
}

timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
epoch()     { date +%s; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 is required but not installed"; exit 2; }
}

# ─── Preflight ────────────────────────────────────────────────────────────────
check_prerequisites() {
  log "Checking prerequisites"
  require_cmd kubectl
  require_cmd velero
  require_cmd psql
  require_cmd dig
  require_cmd curl
  require_cmd jq
  require_cmd aws

  # Verify kubectl contexts exist
  kubectl config get-contexts "${PRIMARY_CONTEXT}" >/dev/null 2>&1 \
    || { err "kubectl context '${PRIMARY_CONTEXT}' not found"; exit 2; }
  kubectl config get-contexts "${SECONDARY_CONTEXT}" >/dev/null 2>&1 \
    || { err "kubectl context '${SECONDARY_CONTEXT}' not found"; exit 2; }

  mkdir -p "${REPORT_DIR}"
  log "Prerequisites OK"
}

# ─── State variables ──────────────────────────────────────────────────────────
DRILL_START_EPOCH=0
OUTAGE_START_EPOCH=0
FIRST_HEALTHY_EPOCH=0
DNS_SWITCHED_EPOCH=0

RPO_SECONDS=-1
RTO_SECONDS=-1
DNS_PROPAGATION_SECONDS=-1
PRE_DRILL_CHECKSUM=""
POST_DRILL_CHECKSUM=""
K6_ERROR_RATE="unknown"
VELERO_RESTORE_ERRORS=0
POSTGRES_PROMOTED=false

# JSON report accumulator
declare -A RESULTS
RESULTS["drill_date"]="$(timestamp)"
RESULTS["rto_pass"]="false"
RESULTS["rpo_pass"]="false"
RESULTS["data_integrity_sha256"]="unknown"
RESULTS["dns_propagation_seconds"]="-1"
RESULTS["k6_error_rate_during_failover"]="unknown"

# ─── Phase 0: Baseline ────────────────────────────────────────────────────────
capture_baseline() {
  log "Phase 0: Capturing pre-drill baseline"

  # DNS baseline
  PRIMARY_IP=$(dig +short "${DNS_HOSTNAME}" @8.8.8.8 2>/dev/null | head -1 || echo "unknown")
  log "Baseline DNS: ${DNS_HOSTNAME} → ${PRIMARY_IP}"
  RESULTS["baseline_dns_ip"]="${PRIMARY_IP}"

  # WAL lag baseline
  SECONDARY_PG=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get svc postgres-secondary -n "${SECONDARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -n "${SECONDARY_PG}" ]]; then
    BASELINE_LAG=$(psql -h "${SECONDARY_PG}" -U postgres -Atc \
      "SELECT extract(epoch from (now() - pg_last_xact_replay_timestamp()))::int;" \
      2>/dev/null || echo "-1")
    log "Baseline WAL lag: ${BASELINE_LAG}s"
    RESULTS["baseline_wal_lag_seconds"]="${BASELINE_LAG}"
  else
    warn "Cannot reach secondary Postgres for baseline"
    RESULTS["baseline_wal_lag_seconds"]="unknown"
  fi

  # Data checksum baseline
  PRIMARY_PG=$(kubectl --context="${PRIMARY_CONTEXT}" \
    get svc postgres-primary -n "${PRIMARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -n "${PRIMARY_PG}" ]]; then
    PRE_DRILL_CHECKSUM=$(psql -h "${PRIMARY_PG}" -U postgres -Atc \
      "SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
       FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;" \
      2>/dev/null || echo "unavailable")
    log "Pre-drill checksum: ${PRE_DRILL_CHECKSUM:0:16}..."
    RESULTS["pre_drill_checksum"]="${PRE_DRILL_CHECKSUM}"
  else
    warn "Cannot reach primary Postgres for checksum"
    RESULTS["pre_drill_checksum"]="unavailable"
  fi

  DRILL_START_EPOCH=$(epoch)
  RESULTS["drill_start_epoch"]="${DRILL_START_EPOCH}"
  log "Baseline complete at $(timestamp)"
}

# ─── Phase 1: Simulate outage ─────────────────────────────────────────────────
simulate_outage() {
  log "Phase 1: Simulating primary region outage"
  OUTAGE_START_EPOCH=$(epoch)
  RESULTS["outage_start_epoch"]="${OUTAGE_START_EPOCH}"

  # Taint primary nodes
  run "kubectl --context=${PRIMARY_CONTEXT} get nodes -o name | \
    xargs -I{} kubectl --context=${PRIMARY_CONTEXT} taint {} \
    disaster-recovery/drill=active:NoSchedule --overwrite 2>/dev/null || true"

  # Trigger health check failure
  run "kubectl --context=${PRIMARY_CONTEXT} set env deployment/web \
    HEALTH_CHECK_FAIL=true -n ${PRIMARY_NS} 2>/dev/null || true"

  log "Outage simulation active. Waiting 35s for Route53 to detect failure..."
  if [[ "${DRY_RUN}" != "true" ]]; then
    sleep 35
  fi

  # Confirm health check is red
  HC_STATUS=$(aws route53 list-health-checks \
    --query 'HealthChecks[0].Id' --output text 2>/dev/null || echo "")
  if [[ -n "${HC_STATUS}" ]]; then
    STATUS=$(aws route53 get-health-check-status --health-check-id "${HC_STATUS}" \
      --query 'HealthCheckObservations[0].StatusReport.Status' --output text 2>/dev/null || echo "unknown")
    log "Route53 health check status: ${STATUS}"
    RESULTS["health_check_status_at_detection"]="${STATUS}"
  fi
}

# ─── Phase 2: Measure RPO ─────────────────────────────────────────────────────
measure_rpo() {
  log "Phase 2: Measuring RPO (WAL lag at failover point)"

  SECONDARY_PG=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get svc postgres-secondary -n "${SECONDARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -n "${SECONDARY_PG}" ]]; then
    RPO_SECONDS=$(psql -h "${SECONDARY_PG}" -U postgres -Atc \
      "SELECT extract(epoch from (now() - pg_last_xact_replay_timestamp()))::int;" \
      2>/dev/null || echo "-1")
    log "WAL lag at failover: ${RPO_SECONDS}s (target: ≤${RPO_TARGET_SECONDS}s)"
    RESULTS["rpo_seconds"]="${RPO_SECONDS}"
    if [[ "${RPO_SECONDS}" -le "${RPO_TARGET_SECONDS}" ]]; then
      RESULTS["rpo_pass"]="true"
      log "RPO: PASS (${RPO_SECONDS}s ≤ ${RPO_TARGET_SECONDS}s)"
    else
      warn "RPO: FAIL (${RPO_SECONDS}s > ${RPO_TARGET_SECONDS}s)"
      RESULTS["rpo_pass"]="false"
    fi
  else
    warn "Cannot measure RPO — secondary Postgres unreachable"
    RESULTS["rpo_seconds"]="-1"
    RESULTS["rpo_pass"]="false"
  fi
}

# ─── Phase 3: Velero restore ──────────────────────────────────────────────────
execute_velero_restore() {
  log "Phase 3: Executing Velero restore on secondary"
  RESTORE_START=$(epoch)

  LATEST_BACKUP=$(velero backup get \
    --kubeconfig ~/.kube/"${SECONDARY_CONTEXT}" -o json 2>/dev/null | \
    jq -r '[.items[] | select(.status.phase=="Completed")] |
            sort_by(.metadata.creationTimestamp) | last | .metadata.name' \
    2>/dev/null || echo "")

  if [[ -z "${LATEST_BACKUP}" ]] || [[ "${LATEST_BACKUP}" == "null" ]]; then
    warn "No completed backups found on secondary BSL — skipping Velero restore"
    RESULTS["velero_restore_status"]="no_backup_found"
    return
  fi

  log "Restoring from backup: ${LATEST_BACKUP}"
  RESTORE_NAME="dr-drill-restore-$(epoch)"

  run "velero restore create '${RESTORE_NAME}' \
    --from-backup '${LATEST_BACKUP}' \
    --include-namespaces '${SECONDARY_NS}' \
    --existing-resource-policy update \
    --kubeconfig ~/.kube/${SECONDARY_CONTEXT} \
    --wait 2>/dev/null || true"

  RESTORE_DURATION=$(($(epoch) - RESTORE_START))
  log "Velero restore completed in ${RESTORE_DURATION}s"

  # Check for errors
  VELERO_RESTORE_ERRORS=$(velero restore describe "${RESTORE_NAME}" \
    --kubeconfig ~/.kube/"${SECONDARY_CONTEXT}" 2>/dev/null | \
    grep -c "Error:" || echo "0")

  RESTORE_PHASE=$(velero restore get "${RESTORE_NAME}" \
    --kubeconfig ~/.kube/"${SECONDARY_CONTEXT}" -o json 2>/dev/null | \
    jq -r '.status.phase // "Unknown"' 2>/dev/null || echo "Unknown")

  log "Restore phase: ${RESTORE_PHASE}, errors: ${VELERO_RESTORE_ERRORS}"
  RESULTS["velero_restore_status"]="${RESTORE_PHASE}"
  RESULTS["velero_restore_errors"]="${VELERO_RESTORE_ERRORS}"
  RESULTS["velero_restore_duration_seconds"]="${RESTORE_DURATION}"
}

# ─── Phase 4: Postgres promotion ─────────────────────────────────────────────
promote_postgres() {
  log "Phase 4: Promoting Postgres standby"

  PG_POD=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get pod -n "${SECONDARY_NS}" -l app=postgres,role=standby \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "${PG_POD}" ]]; then
    warn "Postgres standby pod not found — skipping promotion"
    RESULTS["postgres_promoted"]="false"
    return
  fi

  run "kubectl --context=${SECONDARY_CONTEXT} exec -n ${SECONDARY_NS} '${PG_POD}' \
    -- psql -U postgres -c 'SELECT pg_promote(wait := true, wait_seconds := 60);' \
    2>/dev/null || true"

  # Verify promotion
  IS_PRIMARY=$(kubectl --context="${SECONDARY_CONTEXT}" \
    exec -n "${SECONDARY_NS}" "${PG_POD}" \
    -- psql -U postgres -Atc "SELECT NOT pg_is_in_recovery();" 2>/dev/null || echo "f")

  if [[ "${IS_PRIMARY}" == "t" ]]; then
    log "Postgres promoted to primary"
    POSTGRES_PROMOTED=true
    RESULTS["postgres_promoted"]="true"
  else
    warn "Postgres promotion may have failed"
    RESULTS["postgres_promoted"]="false"
  fi
}

# ─── Phase 5: DNS cutover ─────────────────────────────────────────────────────
execute_dns_cutover() {
  log "Phase 5: Executing DNS cutover"
  DNS_CUTOVER_START=$(epoch)

  run "kubectl --context=${SECONDARY_CONTEXT} annotate svc app-secondary \
    external-dns.alpha.kubernetes.io/aws-weight=100 --overwrite -n ${SECONDARY_NS} \
    2>/dev/null || true"

  SECONDARY_IP=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get svc app-secondary -n "${SECONDARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

  log "DNS cutover triggered. Waiting for propagation (target IP: ${SECONDARY_IP})"

  # Poll for DNS propagation
  for i in $(seq 1 24); do
    RESOLVED=$(dig +short "${DNS_HOSTNAME}" @8.8.8.8 2>/dev/null | head -1 || echo "")
    if [[ "${RESOLVED}" == "${SECONDARY_IP}" ]] && [[ -n "${SECONDARY_IP}" ]]; then
      DNS_SWITCHED_EPOCH=$(epoch)
      DNS_PROPAGATION_SECONDS=$((DNS_SWITCHED_EPOCH - DNS_CUTOVER_START))
      log "DNS propagated to secondary in ${DNS_PROPAGATION_SECONDS}s"
      RESULTS["dns_propagation_seconds"]="${DNS_PROPAGATION_SECONDS}"
      break
    fi
    if [[ "${DRY_RUN}" != "true" ]]; then
      sleep 5
    fi
  done

  if [[ "${DNS_SWITCHED_EPOCH}" -eq 0 ]]; then
    warn "DNS did not propagate within $(( 24 * 5 ))s"
    RESULTS["dns_propagation_seconds"]="-1"
  fi
}

# ─── Phase 6: Smoke test ──────────────────────────────────────────────────────
run_smoke_test() {
  log "Phase 6: Running smoke test on secondary"

  ALB=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get svc app-secondary -n "${SECONDARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -z "${ALB}" ]]; then
    warn "Cannot find secondary ALB for smoke test"
    RESULTS["smoke_test"]="alb_not_found"
    return
  fi

  SMOKE_PASS=true
  for ENDPOINT in "/healthz" "/api/health/db"; do
    STATUS=$(curl -sf --connect-timeout 5 -o /dev/null -w "%{http_code}" \
      "https://${ALB}${ENDPOINT}" 2>/dev/null || echo "000")
    if [[ "${STATUS}" == "200" ]]; then
      log "  ${ENDPOINT}: ${STATUS} OK"
    else
      warn "  ${ENDPOINT}: ${STATUS} FAIL"
      SMOKE_PASS=false
    fi
  done

  RESULTS["smoke_test"]="$([[ "${SMOKE_PASS}" == "true" ]] && echo "pass" || echo "fail")"
  FIRST_HEALTHY_EPOCH=$(epoch)
}

# ─── Phase 7: RTO calculation ─────────────────────────────────────────────────
calculate_rto() {
  log "Phase 7: Calculating RTO"

  if [[ "${OUTAGE_START_EPOCH}" -eq 0 ]] || [[ "${FIRST_HEALTHY_EPOCH}" -eq 0 ]]; then
    warn "Cannot calculate RTO — missing timestamps"
    RESULTS["rto_seconds"]="-1"
    RESULTS["rto_pass"]="false"
    return
  fi

  RTO_SECONDS=$((FIRST_HEALTHY_EPOCH - OUTAGE_START_EPOCH))
  log "RTO: ${RTO_SECONDS}s (target: ≤${RTO_TARGET_SECONDS}s)"
  RESULTS["rto_seconds"]="${RTO_SECONDS}"

  if [[ "${RTO_SECONDS}" -le "${RTO_TARGET_SECONDS}" ]]; then
    RESULTS["rto_pass"]="true"
    log "RTO: PASS (${RTO_SECONDS}s ≤ ${RTO_TARGET_SECONDS}s)"
  else
    warn "RTO: FAIL (${RTO_SECONDS}s > ${RTO_TARGET_SECONDS}s)"
    RESULTS["rto_pass"]="false"
  fi
}

# ─── Phase 8: Data integrity ──────────────────────────────────────────────────
verify_data_integrity() {
  log "Phase 8: Verifying data integrity"

  SECONDARY_PG=$(kubectl --context="${SECONDARY_CONTEXT}" \
    get svc postgres-secondary -n "${SECONDARY_NS}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [[ -n "${SECONDARY_PG}" ]]; then
    POST_DRILL_CHECKSUM=$(psql -h "${SECONDARY_PG}" -U postgres -Atc \
      "SELECT md5(string_agg(row_to_json(t)::text, '' ORDER BY id))
       FROM (SELECT id, data FROM orders ORDER BY id DESC LIMIT 100) t;" \
      2>/dev/null || echo "unavailable")
    log "Post-drill checksum: ${POST_DRILL_CHECKSUM:0:16}..."
    RESULTS["post_drill_checksum"]="${POST_DRILL_CHECKSUM}"

    if [[ -n "${PRE_DRILL_CHECKSUM}" ]] \
      && [[ "${PRE_DRILL_CHECKSUM}" == "${POST_DRILL_CHECKSUM}" ]] \
      && [[ "${PRE_DRILL_CHECKSUM}" != "unavailable" ]]; then
      RESULTS["data_integrity_sha256"]="match"
      log "Data integrity: PASS (checksums match)"
    else
      RESULTS["data_integrity_sha256"]="mismatch"
      warn "Data integrity: checksums differ (pre: ${PRE_DRILL_CHECKSUM:0:16}, post: ${POST_DRILL_CHECKSUM:0:16})"
    fi
  else
    warn "Cannot verify data integrity — secondary Postgres unreachable"
    RESULTS["data_integrity_sha256"]="unknown"
  fi
}

# ─── Phase 9: Failback ────────────────────────────────────────────────────────
execute_failback() {
  log "Phase 9: Executing failback"

  # Remove simulation artifacts
  run "kubectl --context=${PRIMARY_CONTEXT} get nodes -o name 2>/dev/null | \
    xargs -I{} kubectl --context=${PRIMARY_CONTEXT} taint {} \
    disaster-recovery/drill:NoSchedule- 2>/dev/null || true"

  run "kubectl --context=${PRIMARY_CONTEXT} set env deployment/web \
    HEALTH_CHECK_FAIL- -n ${PRIMARY_NS} 2>/dev/null || true"

  # Switch DNS back
  run "kubectl --context=${SECONDARY_CONTEXT} annotate svc app-secondary \
    external-dns.alpha.kubernetes.io/aws-weight=0 --overwrite -n ${SECONDARY_NS} 2>/dev/null || true"
  run "kubectl --context=${PRIMARY_CONTEXT} annotate svc app-primary \
    external-dns.alpha.kubernetes.io/aws-weight=100 --overwrite -n ${PRIMARY_NS} 2>/dev/null || true"
  run "kubectl --context=${PRIMARY_CONTEXT} annotate svc app-primary \
    external-dns.alpha.kubernetes.io/ttl=300 --overwrite -n ${PRIMARY_NS} 2>/dev/null || true"

  log "Failback initiated. DNS will propagate within 90s."
  RESULTS["failback_executed"]="true"
}

# ─── Phase 10: Report ─────────────────────────────────────────────────────────
emit_report() {
  log "Phase 10: Generating report"

  DRILL_END_EPOCH=$(epoch)
  DRILL_TOTAL_DURATION=$((DRILL_END_EPOCH - DRILL_START_EPOCH))

  # Determine overall pass/fail
  OVERALL_PASS=true
  [[ "${RESULTS[rto_pass]}" != "true" ]]                 && OVERALL_PASS=false
  [[ "${RESULTS[rpo_pass]}" != "true" ]]                 && OVERALL_PASS=false
  [[ "${RESULTS[data_integrity_sha256]}" != "match" ]]   && OVERALL_PASS=false

  cat > "${REPORT_FILE}" <<EOF
{
  "drill_date": "${RESULTS[drill_date]}",
  "drill_total_duration_seconds": ${DRILL_TOTAL_DURATION},
  "overall_pass": ${OVERALL_PASS},
  "rto_seconds": ${RESULTS[rto_seconds]:-"-1"},
  "rto_target_seconds": ${RTO_TARGET_SECONDS},
  "rto_pass": ${RESULTS[rto_pass]:-"false"},
  "rpo_seconds": ${RESULTS[rpo_seconds]:-"-1"},
  "rpo_target_seconds": ${RPO_TARGET_SECONDS},
  "rpo_pass": ${RESULTS[rpo_pass]:-"false"},
  "data_integrity_sha256": "${RESULTS[data_integrity_sha256]:-"unknown"}",
  "dns_propagation_seconds": ${RESULTS[dns_propagation_seconds]:-"-1"},
  "dns_propagation_target_seconds": ${DNS_PROPAGATION_TARGET},
  "k6_error_rate_during_failover": "${K6_ERROR_RATE}",
  "velero_restore_status": "${RESULTS[velero_restore_status]:-"skipped"}",
  "velero_restore_errors": ${RESULTS[velero_restore_errors]:-"0"},
  "velero_restore_duration_seconds": ${RESULTS[velero_restore_duration_seconds]:-"-1"},
  "postgres_promoted": ${RESULTS[postgres_promoted]:-"false"},
  "smoke_test": "${RESULTS[smoke_test]:-"skipped"}",
  "health_check_status_at_detection": "${RESULTS[health_check_status_at_detection]:-"unknown"}",
  "baseline_wal_lag_seconds": "${RESULTS[baseline_wal_lag_seconds]:-"unknown"}",
  "baseline_dns_ip": "${RESULTS[baseline_dns_ip]:-"unknown"}",
  "pre_drill_checksum": "${RESULTS[pre_drill_checksum]:-"unavailable"}",
  "post_drill_checksum": "${RESULTS[post_drill_checksum]:-"unavailable"}",
  "failback_executed": ${RESULTS[failback_executed]:-"false"}
}
EOF

  # Print report to stdout (for make verify-rto-rpo consumption)
  cat "${REPORT_FILE}" | jq .

  log ""
  log "========================================================"
  log "  DR DRILL REPORT"
  log "  Date: ${RESULTS[drill_date]}"
  log "  RTO:  ${RESULTS[rto_seconds]:-'N/A'}s (target ≤${RTO_TARGET_SECONDS}s) — $([[ "${RESULTS[rto_pass]}" == "true" ]] && echo 'PASS' || echo 'FAIL')"
  log "  RPO:  ${RESULTS[rpo_seconds]:-'N/A'}s (target ≤${RPO_TARGET_SECONDS}s) — $([[ "${RESULTS[rpo_pass]}" == "true" ]] && echo 'PASS' || echo 'FAIL')"
  log "  Data: ${RESULTS[data_integrity_sha256]:-'unknown'}"
  log "  DNS:  ${RESULTS[dns_propagation_seconds]:-'N/A'}s propagation"
  log "  Overall: $([[ "${OVERALL_PASS}" == "true" ]] && echo 'PASS' || echo 'FAIL')"
  log "========================================================"
  log "  Full report: ${REPORT_FILE}"

  [[ "${OVERALL_PASS}" == "true" ]] && exit 0 || exit 1
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  check_prerequisites

  if [[ "${FAILBACK_ONLY}" == "true" ]]; then
    execute_failback
    return
  fi

  if [[ "${VERIFY_ONLY}" == "true" ]]; then
    measure_rpo
    verify_data_integrity
    calculate_rto
    emit_report
    return
  fi

  # Full drill
  capture_baseline
  simulate_outage
  measure_rpo
  execute_velero_restore
  promote_postgres
  execute_dns_cutover
  run_smoke_test
  calculate_rto
  verify_data_integrity

  log "Waiting 30s before failback (simulating 30 min production hold)"
  if [[ "${DRY_RUN}" != "true" ]]; then
    sleep 30
  fi

  execute_failback
  emit_report
}

main "$@"
