# =============================================================================
# Makefile — Project 07 Disaster Recovery
#
# All targets operate against the PRIMARY cluster unless prefixed with
# CLUSTER=secondary or explicitly documented as multi-cluster.
#
# Prerequisites:
#   - kubectl configured with contexts "primary" and "secondary"
#   - velero CLI installed
#   - terraform installed (for infra targets)
#   - k6 installed (for perf targets)
#   - psql installed (for db verification targets)
#   - aws CLI configured
#
# Usage:
#   make backup             # trigger an immediate Velero backup
#   make restore            # restore latest backup on secondary cluster
#   make simulate-outage    # block primary region (drill only)
#   make failover           # execute full failover to secondary
#   make verify-rto-rpo     # measure and report RTO + RPO
#   make failback           # restore primary, switch DNS back
# =============================================================================

# ─── Configuration ────────────────────────────────────────────────────────────
PRIMARY_CONTEXT   ?= primary
SECONDARY_CONTEXT ?= secondary
PRIMARY_NS        ?= production
SECONDARY_NS      ?= production
PRIMARY_BUCKET    ?= dr-velero-primary-backup
SECONDARY_BUCKET  ?= dr-velero-secondary-backup
PRIMARY_REGION    ?= us-east-1
SECONDARY_REGION  ?= us-west-2
DNS_HOSTNAME      ?= api.example.com
K6_SCRIPT         := tests/k6/during-drill.js
REPORT_DIR        := /tmp/dr-drill-reports
TF_DIR            := infra/replication

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
RESET  := \033[0m
BOLD   := \033[1m

define log
  @printf '$(GREEN)[dr-lab] $(RESET)%s\n' "$(1)"
endef

define warn
  @printf '$(YELLOW)[dr-lab] WARN: $(RESET)%s\n' "$(1)"
endef

define die
  @printf '$(RED)[dr-lab] ERROR: $(RESET)%s\n' "$(1)" && exit 1
endef

# ─── Default target ───────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf '$(BOLD)Project 07 — Disaster Recovery Lab$(RESET)\n\n'
	@printf '$(BOLD)Backup & Restore$(RESET)\n'
	@printf '  make backup                    Trigger immediate Velero backup on primary\n'
	@printf '  make backup-status             Show recent backup status\n'
	@printf '  make restore                   Restore latest backup on secondary\n'
	@printf '  make restore-status            Show restore status on secondary\n'
	@printf '  make pg-backup                 Trigger WAL-G base backup manually\n'
	@printf '  make pg-wal-lag                Show current Postgres WAL replication lag\n\n'
	@printf '$(BOLD)Infrastructure$(RESET)\n'
	@printf '  make velero-install            Install Velero on primary + secondary\n'
	@printf '  make tf-plan                   Terraform plan for S3 replication\n'
	@printf '  make tf-apply                  Terraform apply S3 replication\n'
	@printf '  make tf-destroy                Terraform destroy (WARNING: deletes buckets)\n\n'
	@printf '$(BOLD)DR Drill$(RESET)\n'
	@printf '  make simulate-outage           Block primary region (drill simulation)\n'
	@printf '  make failover                  Execute full failover to secondary\n'
	@printf '  make verify-rto-rpo            Measure and report actual RTO + RPO\n'
	@printf '  make failback                  Restore primary region, switch DNS back\n'
	@printf '  make drill                     Full automated drill: simulate → failover → verify → failback\n\n'
	@printf '$(BOLD)Verification$(RESET)\n'
	@printf '  make smoke-primary             Smoke test on primary cluster\n'
	@printf '  make smoke-secondary           Smoke test on secondary cluster\n'
	@printf '  make dns-check                 Show current DNS resolution for $(DNS_HOSTNAME)\n'
	@printf '  make replication-check         Check S3 CRR replication health\n\n'
	@printf '$(BOLD)Performance$(RESET)\n'
	@printf '  make perf                      Run k6 load test (normal operation baseline)\n'
	@printf '  make perf-during-drill         Run k6 during drill (already-running drill)\n\n'
	@printf '$(BOLD)Cleanup$(RESET)\n'
	@printf '  make down                      Remove drill simulation artifacts\n'

# ─── Backup & Restore ─────────────────────────────────────────────────────────

.PHONY: backup
backup:
	$(call log,Triggering immediate Velero backup on primary cluster)
	velero backup create manual-$(shell date +%s) \
	  --include-namespaces $(PRIMARY_NS) \
	  --ttl 24h \
	  --kubeconfig ~/.kube/$(PRIMARY_CONTEXT) \
	  --wait
	$(call log,Backup complete. Listing recent backups:)
	velero backup get --kubeconfig ~/.kube/$(PRIMARY_CONTEXT)

.PHONY: backup-status
backup-status:
	$(call log,Velero backup status — primary cluster)
	velero backup get --kubeconfig ~/.kube/$(PRIMARY_CONTEXT)
	@echo ""
	$(call log,Recent backup schedules:)
	velero schedule get --kubeconfig ~/.kube/$(PRIMARY_CONTEXT)

.PHONY: restore
restore:
	$(call log,Restoring latest backup on SECONDARY cluster)
	@LATEST=$$(velero backup get \
	  --kubeconfig ~/.kube/$(SECONDARY_CONTEXT) -o json 2>/dev/null | \
	  jq -r '[.items[] | select(.status.phase=="Completed")] | \
	         sort_by(.metadata.creationTimestamp) | last | .metadata.name' \
	  2>/dev/null); \
	if [ -z "$$LATEST" ] || [ "$$LATEST" = "null" ]; then \
	  echo "ERROR: No completed backups found on secondary BSL"; \
	  exit 1; \
	fi; \
	echo "Restoring from: $$LATEST"; \
	velero restore create dr-restore-$(shell date +%s) \
	  --from-backup "$$LATEST" \
	  --include-namespaces $(SECONDARY_NS) \
	  --existing-resource-policy update \
	  --kubeconfig ~/.kube/$(SECONDARY_CONTEXT) \
	  --wait

.PHONY: restore-status
restore-status:
	$(call log,Velero restore status — secondary cluster)
	velero restore get --kubeconfig ~/.kube/$(SECONDARY_CONTEXT)

.PHONY: pg-backup
pg-backup:
	$(call log,Triggering WAL-G base backup on primary Postgres)
	kubectl --context=$(PRIMARY_CONTEXT) create job \
	  --from=cronjob/postgres-base-backup \
	  pg-manual-backup-$(shell date +%s) \
	  -n $(PRIMARY_NS)
	$(call log,Job created. Watch with: kubectl --context=$(PRIMARY_CONTEXT) logs -f job/pg-manual-backup-* -n $(PRIMARY_NS))

.PHONY: pg-wal-lag
pg-wal-lag:
	$(call log,Checking WAL replication lag on SECONDARY Postgres)
	@SECONDARY_PG=$$(kubectl --context=$(SECONDARY_CONTEXT) \
	  get svc postgres-secondary -n $(SECONDARY_NS) \
	  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$SECONDARY_PG" ]; then \
	  echo "ERROR: Cannot find secondary postgres service"; exit 1; \
	fi; \
	psql -h "$$SECONDARY_PG" -U postgres -c \
	  "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag, \
	          CASE WHEN now() - pg_last_xact_replay_timestamp() <= interval '30s' \
	               THEN 'WITHIN RPO TARGET' ELSE 'RPO BREACH' END AS status;"

# ─── Infrastructure ───────────────────────────────────────────────────────────

.PHONY: velero-install
velero-install:
	$(call log,Installing Velero on primary cluster)
	CLUSTER=primary REGION=$(PRIMARY_REGION) BUCKET=$(PRIMARY_BUCKET) \
	  bash infra/velero/install.sh
	$(call log,Installing Velero on secondary cluster)
	CLUSTER=secondary REGION=$(SECONDARY_REGION) BUCKET=$(SECONDARY_BUCKET) \
	  bash infra/velero/install.sh

.PHONY: tf-plan
tf-plan:
	$(call log,Terraform plan — S3 cross-region replication)
	cd $(TF_DIR) && terraform init -backend-config=backend.tfvars
	cd $(TF_DIR) && terraform plan \
	  -var="primary_region=$(PRIMARY_REGION)" \
	  -var="secondary_region=$(SECONDARY_REGION)" \
	  -out=tfplan

.PHONY: tf-apply
tf-apply:
	$(call log,Terraform apply — S3 cross-region replication)
	cd $(TF_DIR) && terraform apply tfplan

.PHONY: tf-destroy
tf-destroy:
	$(call warn,WARNING: This will destroy S3 buckets and all backups!)
	@read -p "Type 'yes' to confirm: " confirm && \
	  [ "$$confirm" = "yes" ] || (echo "Aborted" && exit 1)
	cd $(TF_DIR) && terraform destroy \
	  -var="primary_region=$(PRIMARY_REGION)" \
	  -var="secondary_region=$(SECONDARY_REGION)"

# ─── DR Drill ─────────────────────────────────────────────────────────────────

.PHONY: simulate-outage
simulate-outage:
	$(call log,DRILL: Simulating primary region outage)
	@echo "Tainting primary nodes (NoSchedule)"
	kubectl --context=$(PRIMARY_CONTEXT) get nodes -o name | \
	  xargs -I{} kubectl --context=$(PRIMARY_CONTEXT) taint {} \
	  disaster-recovery/drill=active:NoSchedule --overwrite 2>/dev/null || true
	@echo "Setting HEALTH_CHECK_FAIL on primary web deployment"
	kubectl --context=$(PRIMARY_CONTEXT) set env deployment/web \
	  HEALTH_CHECK_FAIL=true -n $(PRIMARY_NS) 2>/dev/null || true
	$(call log,Outage simulated. Route53 health check will detect failure in ~30s)
	$(call log,Run 'make failover' after confirming health check is RED)

.PHONY: failover
failover:
	$(call log,EXECUTING FAILOVER to secondary region)
	@mkdir -p $(REPORT_DIR)
	@FAILOVER_START=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	echo "Failover started: $$FAILOVER_START" | tee $(REPORT_DIR)/failover-log.txt
	@echo "Step 1: Measuring WAL lag"
	$(MAKE) pg-wal-lag 2>&1 | tee -a $(REPORT_DIR)/failover-log.txt
	@echo "Step 2: Lowering DNS TTL"
	kubectl --context=$(SECONDARY_CONTEXT) annotate svc app-secondary \
	  external-dns.alpha.kubernetes.io/ttl=60 --overwrite -n $(SECONDARY_NS) || true
	@echo "Step 3: Starting Velero restore"
	$(MAKE) restore 2>&1 | tee -a $(REPORT_DIR)/failover-log.txt
	@echo "Step 4: Promoting Postgres"
	$(MAKE) pg-promote 2>&1 | tee -a $(REPORT_DIR)/failover-log.txt
	@echo "Step 5: Smoke test"
	$(MAKE) smoke-secondary 2>&1 | tee -a $(REPORT_DIR)/failover-log.txt
	@echo "Step 6: DNS cutover"
	kubectl --context=$(SECONDARY_CONTEXT) annotate svc app-secondary \
	  external-dns.alpha.kubernetes.io/aws-weight=100 --overwrite -n $(SECONDARY_NS)
	@echo "Failover complete at $$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	  | tee -a $(REPORT_DIR)/failover-log.txt
	$(MAKE) dns-check

.PHONY: pg-promote
pg-promote:
	$(call log,Promoting Postgres standby to primary in secondary region)
	@PG_POD=$$(kubectl --context=$(SECONDARY_CONTEXT) \
	  get pod -n $(SECONDARY_NS) -l app=postgres,role=standby \
	  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$PG_POD" ]; then \
	  echo "ERROR: Secondary Postgres standby pod not found"; exit 1; \
	fi; \
	kubectl --context=$(SECONDARY_CONTEXT) exec -n $(SECONDARY_NS) "$$PG_POD" \
	  -- psql -U postgres -c "SELECT pg_promote(wait := true, wait_seconds := 60);" \
	  2>&1 || echo "pg_promote: might need recovery.signal method for older PG"

.PHONY: verify-rto-rpo
verify-rto-rpo:
	$(call log,Running automated RTO/RPO verification)
	@bash tests/drill.sh --verify-only 2>&1 | tee $(REPORT_DIR)/verify-$(shell date +%s).json
	@echo ""
	$(call log,Verification report:)
	@cat $(REPORT_DIR)/verify-*.json 2>/dev/null | jq . || true

.PHONY: failback
failback:
	$(call log,EXECUTING FAILBACK to primary region)
	@echo "Step 1: Verify primary is healthy"
	kubectl --context=$(PRIMARY_CONTEXT) get nodes 2>/dev/null \
	  || { echo "ERROR: Primary cluster not reachable"; exit 1; }
	@echo "Step 2: Remove drill simulation artifacts"
	$(MAKE) down
	@echo "Step 3: Smoke test on primary"
	$(MAKE) smoke-primary
	@echo "Step 4: DNS failback"
	kubectl --context=$(SECONDARY_CONTEXT) annotate svc app-secondary \
	  external-dns.alpha.kubernetes.io/aws-weight=0 --overwrite -n $(SECONDARY_NS) || true
	kubectl --context=$(PRIMARY_CONTEXT) annotate svc app-primary \
	  external-dns.alpha.kubernetes.io/aws-weight=100 --overwrite -n $(PRIMARY_NS) || true
	@echo "Step 5: Restore TTL to 300s"
	kubectl --context=$(PRIMARY_CONTEXT) annotate svc app-primary \
	  external-dns.alpha.kubernetes.io/ttl=300 --overwrite -n $(PRIMARY_NS) || true
	$(call log,Failback complete. Verifying DNS:)
	$(MAKE) dns-check

.PHONY: drill
drill:
	$(call log,Starting full automated DR drill)
	@echo "This will: simulate-outage → failover → verify-rto-rpo → failback"
	@read -p "Start drill? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 0
	@DRILL_START=$$(date +%s); \
	$(MAKE) simulate-outage && sleep 35 && \
	$(MAKE) failover && \
	$(MAKE) verify-rto-rpo && \
	sleep 900 && \
	$(MAKE) failback && \
	DRILL_END=$$(date +%s); \
	echo "Total drill duration: $$((DRILL_END - DRILL_START)) seconds"

# ─── Verification ─────────────────────────────────────────────────────────────

.PHONY: smoke-primary
smoke-primary:
	$(call log,Smoke test — primary cluster)
	@ALB=$$(kubectl --context=$(PRIMARY_CONTEXT) \
	  get svc app-primary -n $(PRIMARY_NS) \
	  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$ALB" ]; then echo "WARN: Cannot find primary ALB"; exit 0; fi; \
	echo "Testing https://$$ALB/healthz"; \
	curl -sf --connect-timeout 5 "https://$$ALB/healthz" | jq . || \
	  curl -sf --connect-timeout 5 "http://$$ALB/healthz" | jq .

.PHONY: smoke-secondary
smoke-secondary:
	$(call log,Smoke test — secondary cluster)
	@ALB=$$(kubectl --context=$(SECONDARY_CONTEXT) \
	  get svc app-secondary -n $(SECONDARY_NS) \
	  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$ALB" ]; then echo "ERROR: Cannot find secondary ALB"; exit 1; fi; \
	echo "Testing https://$$ALB/healthz"; \
	curl -sf --connect-timeout 5 "https://$$ALB/healthz" | jq . && \
	echo "Testing https://$$ALB/api/health/db"; \
	curl -sf --connect-timeout 5 "https://$$ALB/api/health/db" | jq .

.PHONY: dns-check
dns-check:
	$(call log,DNS resolution check for $(DNS_HOSTNAME))
	@echo "Google DNS (8.8.8.8):    $$(dig +short $(DNS_HOSTNAME) @8.8.8.8 | head -1)"
	@echo "Cloudflare (1.1.1.1):    $$(dig +short $(DNS_HOSTNAME) @1.1.1.1 | head -1)"
	@echo "Quad9 (9.9.9.9):         $$(dig +short $(DNS_HOSTNAME) @9.9.9.9 | head -1)"
	@echo ""
	@echo "Primary ALB IP:   $$(kubectl --context=$(PRIMARY_CONTEXT) get svc app-primary \
	  -n $(PRIMARY_NS) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo 'unknown')"
	@echo "Secondary ALB IP: $$(kubectl --context=$(SECONDARY_CONTEXT) get svc app-secondary \
	  -n $(SECONDARY_NS) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo 'unknown')"

.PHONY: replication-check
replication-check:
	$(call log,Checking S3 cross-region replication health)
	@echo "=== Replication configuration ==="
	aws s3api get-bucket-replication --bucket $(PRIMARY_BUCKET) --region $(PRIMARY_REGION) | jq .
	@echo ""
	@echo "=== Pending replication operations (last 5 min) ==="
	aws cloudwatch get-metric-statistics \
	  --namespace AWS/S3 \
	  --metric-name ReplicationPendingOperations \
	  --dimensions Name=SourceBucket,Value=$(PRIMARY_BUCKET) \
	  --start-time $$(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
	                  date -u -v-5M +%Y-%m-%dT%H:%M:%SZ) \
	  --end-time $$(date -u +%Y-%m-%dT%H:%M:%SZ) \
	  --period 300 --statistics Average \
	  --region $(PRIMARY_REGION) | jq '.Datapoints[0].Average // "no data"'

# ─── Performance ──────────────────────────────────────────────────────────────

.PHONY: perf
perf:
	$(call log,Running k6 load test — normal operation baseline)
	k6 run $(K6_SCRIPT) \
	  --env TARGET=normal \
	  --env BASE_URL=https://$(DNS_HOSTNAME) \
	  --duration 2m \
	  --vus 50

.PHONY: perf-during-drill
perf-during-drill:
	$(call log,Running k6 continuous traffic test during drill)
	k6 run $(K6_SCRIPT) \
	  --env TARGET=drill \
	  --env BASE_URL=https://$(DNS_HOSTNAME) \
	  --duration 20m \
	  --vus 20 \
	  --out json=$(REPORT_DIR)/k6-drill-$(shell date +%s).json

# ─── Cleanup ──────────────────────────────────────────────────────────────────

.PHONY: down
down:
	$(call log,Removing DR drill simulation artifacts)
	@kubectl --context=$(PRIMARY_CONTEXT) get nodes -o name 2>/dev/null | \
	  xargs -I{} kubectl --context=$(PRIMARY_CONTEXT) taint {} \
	  disaster-recovery/drill:NoSchedule- 2>/dev/null || true
	@kubectl --context=$(PRIMARY_CONTEXT) set env deployment/web \
	  HEALTH_CHECK_FAIL- -n $(PRIMARY_NS) 2>/dev/null || true
	@kubectl --context=$(PRIMARY_CONTEXT) delete networkpolicy block-s3-drill \
	  -n $(PRIMARY_NS) 2>/dev/null || true
	$(call log,Drill artifacts removed)
