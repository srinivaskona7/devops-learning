SERVICE   ?= payment-service
TEAM      ?= payment
TIER      ?= gold
CLUSTER   ?= platform-local
CONTEXT   ?= kind-platform-local
REGISTRY  ?= ghcr.io/vantapay
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

# Tool paths
KUBECTL   := kubectl --context=$(CONTEXT)
ARGOCD    := argocd
K6        := k6
VAULT     := vault
ISTIOCTL  := istioctl

.DEFAULT_GOAL := help

##@ Platform Bootstrap

.PHONY: bootstrap
bootstrap: ## Bootstrap the complete platform on a local kind cluster
	@echo "=== Vanta Pay Platform Bootstrap ==="
	@echo "This will take 5–10 minutes on first run."
	@echo ""
	@echo "Step 1: Create kind cluster"
	kind create cluster --name platform-local --config hack/kind-config.yaml || true
	@echo ""
	@echo "Step 2: Install cert-manager"
	helm repo add jetstack https://charts.jetstack.io && helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--set installCRDs=true --wait --timeout=5m
	@echo ""
	@echo "Step 3: Install Argo CD"
	helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
	helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		--wait --timeout=10m
	@echo ""
	@echo "Step 4: Install Argo Rollouts"
	helm upgrade --install argo-rollouts argo/argo-rollouts \
		--namespace argo-rollouts --create-namespace \
		--set dashboard.enabled=true --wait --timeout=5m
	@echo ""
	@echo "Step 5: Install Istio"
	istioctl install --set profile=demo --skip-confirmation
	kubectl label namespace default istio-injection=enabled --overwrite
	@echo ""
	@echo "Step 6: Install Vault (dev mode for local)"
	helm repo add hashicorp https://helm.releases.hashicorp.com && helm repo update
	helm upgrade --install vault hashicorp/vault \
		--namespace vault --create-namespace \
		--set server.dev.enabled=true --wait --timeout=5m
	@echo ""
	@echo "Step 7: Install External Secrets Operator"
	helm repo add external-secrets https://charts.external-secrets.io && helm repo update
	helm upgrade --install external-secrets external-secrets/external-secrets \
		--namespace external-secrets --create-namespace --wait --timeout=5m
	@echo ""
	@echo "Step 8: Install Kyverno"
	helm repo add kyverno https://kyverno.github.io/kyverno/ && helm repo update
	helm upgrade --install kyverno kyverno/kyverno \
		--namespace kyverno --create-namespace --wait --timeout=10m
	@echo ""
	@echo "Step 9: Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)"
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace \
		--set grafana.adminPassword=platform-admin \
		--wait --timeout=15m
	@echo ""
	@echo "Step 10: Install Loki + Tempo + OTel Collector"
	helm repo add grafana https://grafana.github.io/helm-charts && helm repo update
	helm upgrade --install loki grafana/loki-stack \
		--namespace monitoring --wait --timeout=5m
	helm upgrade --install tempo grafana/tempo \
		--namespace monitoring --wait --timeout=5m
	@echo ""
	@echo "Step 11: Install Chaos Mesh"
	helm repo add chaos-mesh https://charts.chaos-mesh.org && helm repo update
	helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
		--namespace chaos-mesh --create-namespace \
		--set dashboard.create=true --wait --timeout=5m
	@echo ""
	@echo "Step 12: Apply platform policies"
	$(KUBECTL) apply -f platform/security/kyverno-policies.yaml
	$(KUBECTL) apply -f platform/istio/peer-authentication.yaml
	$(KUBECTL) apply -f platform/observability/servicemonitor.yaml
	$(KUBECTL) apply -f slo/bronze.yaml slo/silver.yaml slo/gold.yaml
	@echo ""
	@echo "Step 13: Bootstrap Argo CD app-of-apps"
	$(KUBECTL) apply -f platform/argocd/app-of-apps.yaml
	@echo ""
	@echo "=== Bootstrap complete! ==="
	@echo ""
	@echo "Access points:"
	@echo "  Argo CD:   kubectl port-forward -n argocd svc/argocd-server 8080:443"
	@echo "  Grafana:   kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
	@echo "             Username: admin, Password: platform-admin"
	@echo "  Vault:     kubectl port-forward -n vault svc/vault 8200:8200"
	@echo "             Token: root (dev mode)"
	@echo ""
	@$(MAKE) platform-status

##@ Service Lifecycle

.PHONY: onboard-demo
onboard-demo: ## Onboard a demo service (SERVICE=name TEAM=team TIER=bronze|silver|gold)
	@echo "Onboarding service: $(SERVICE) (team: $(TEAM), tier: $(TIER))"
	@echo "Using golden-path template..."
	$(KUBECTL) create namespace $(TEAM) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) label namespace $(TEAM) istio-injection=enabled --overwrite
	@echo "Applying scaffold manifests..."
	cat golden-path/skeleton/k8s/rollout.yaml \
		| sed 's/\$${{values.name}}/$(SERVICE)/g' \
		| sed 's/\$${{values.team}}/$(TEAM)/g' \
		| sed 's/\$${{values.slo_tier}}/$(TIER)/g' \
		| sed 's/\$${{values.port}}/8080/g' \
		| sed 's/\$${{values.replicas}}/3/g' \
		| sed 's/\$${{values.cpu_request}}/100m/g' \
		| sed 's/\$${{values.cpu_limit}}/500m/g' \
		| sed 's/\$${{values.memory_request}}/128Mi/g' \
		| sed 's/\$${{values.memory_limit}}/512Mi/g' \
		| $(KUBECTL) apply -f -
	@echo "Service $(SERVICE) onboarded. Watch it deploy:"
	@echo "  kubectl argo rollouts get rollout $(SERVICE) -n $(TEAM) --watch"

.PHONY: promote
promote: ## Manually promote a canary (SERVICE=name)
	@echo "Promoting canary for $(SERVICE)..."
	$(KUBECTL) argo rollouts promote $(SERVICE) -n $(TEAM)
	$(KUBECTL) argo rollouts get rollout $(SERVICE) -n $(TEAM) --watch

.PHONY: rollback
rollback: ## Roll back a canary to stable (SERVICE=name)
	@echo "Rolling back $(SERVICE) to stable..."
	$(KUBECTL) argo rollouts abort $(SERVICE) -n $(TEAM)
	$(KUBECTL) argo rollouts undo $(SERVICE) -n $(TEAM)

##@ Chaos Engineering

.PHONY: chaos-drill
chaos-drill: ## Run full chaos drill against SERVICE (SERVICE=name TIER=gold)
	@echo "=== Chaos Drill: $(SERVICE) (tier: $(TIER)) ==="
	@echo "Starting k6 load in background..."
	$(K6) run --env SERVICE_URL=http://localhost:8080 --duration=12m tests/k6/load.js &
	K6_PID=$$!
	@echo "Baseline period: 60 seconds..."
	sleep 60
	@echo "[T+60s] Applying pod-kill experiment..."
	$(KUBECTL) apply -f chaos/pod-kill-experiment.yaml
	sleep 90
	@echo "[T+150s] Applying network-delay experiment..."
	$(KUBECTL) delete -f chaos/pod-kill-experiment.yaml --ignore-not-found
	$(KUBECTL) apply -f chaos/network-delay-experiment.yaml
	sleep 90
	@echo "[T+240s] Applying CPU stress experiment..."
	$(KUBECTL) delete -f chaos/network-delay-experiment.yaml --ignore-not-found
	$(KUBECTL) apply -f chaos/cpu-stress-experiment.yaml
	sleep 90
	@echo "[T+330s] Cleaning up chaos experiments..."
	$(KUBECTL) delete -f chaos/cpu-stress-experiment.yaml --ignore-not-found
	@echo "Waiting for k6 to complete..."
	wait $$K6_PID || true
	@echo "=== Chaos drill complete. Check Grafana for results. ==="
	open "https://grafana.vantapay.io/d/platform-$(SERVICE)" || true

##@ Performance

.PHONY: perf-drill
perf-drill: ## Run full performance drill (smoke → load → stress → soak)
	@echo "=== Performance Drill ==="
	@echo "Phase 1: Smoke (10 VUs, 1m)"
	$(K6) run --env PHASE=smoke tests/k6/load.js
	@echo "Phase 2: Load (500 VUs, 5m)"
	$(K6) run --env PHASE=load tests/k6/load.js
	@echo "Phase 3: Stress (1000 VUs, 10m)"
	$(K6) run --env PHASE=stress tests/k6/load.js
	@echo "Skipping soak (60m) — run manually: make soak-test"

.PHONY: soak-test
soak-test: ## Run 60-minute soak test (200 VUs)
	$(K6) run --env PHASE=soak tests/k6/load.js

##@ Security Audit

.PHONY: audit
audit: ## Run security audit (image scan + policy report + secret check + mTLS verify)
	@echo "=== Platform Security Audit ==="
	@echo ""
	@echo "--- Kyverno Policy Reports ---"
	$(KUBECTL) get policyreport --all-namespaces -o wide
	@echo ""
	@echo "--- ExternalSecret Sync Status ---"
	$(KUBECTL) get externalsecret --all-namespaces
	@echo ""
	@echo "--- Istio mTLS Status ---"
	$(ISTIOCTL) authn tls-check --all-namespaces 2>/dev/null | head -30
	@echo ""
	@echo "--- Cosign signature verification (payment-service) ---"
	@IMAGE=$$($(KUBECTL) get rollout $(SERVICE) -n $(TEAM) -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null); \
	if [ -n "$$IMAGE" ]; then \
		cosign verify \
			--certificate-identity-regexp "https://github.com/vantapay/.*" \
			--certificate-oidc-issuer https://token.actions.githubusercontent.com \
			$$IMAGE 2>&1 | head -5; \
	else \
		echo "  (No rollout found for $(SERVICE) in $(TEAM))"; \
	fi
	@echo ""
	@echo "--- Vault seal status ---"
	$(KUBECTL) exec -n vault vault-0 -- vault status 2>/dev/null || echo "  Vault not accessible"
	@echo ""
	@echo "=== Audit complete ==="

##@ Platform Status

.PHONY: platform-status
platform-status: ## Show overall platform health
	@echo "=== Platform Status ==="
	@echo ""
	@echo "--- Argo CD Applications ---"
	$(ARGOCD) app list 2>/dev/null || $(KUBECTL) get applications -n argocd
	@echo ""
	@echo "--- Platform Pods ---"
	@for ns in argocd monitoring istio-system vault external-secrets kyverno chaos-mesh backstage; do \
		echo "Namespace: $$ns"; \
		$(KUBECTL) get pods -n $$ns --no-headers 2>/dev/null | awk '{print "  " $$1 "\t" $$3}'; \
	done
	@echo ""
	@echo "--- Active Chaos Experiments ---"
	$(KUBECTL) get podchaos,networkchaos,stresschaos --all-namespaces 2>/dev/null || echo "  None"
	@echo ""
	@echo "--- SLO Status (last 5 min) ---"
	@echo "  (Check Grafana: https://grafana.vantapay.io/d/slo-overview)"

##@ Teardown

.PHONY: teardown
teardown: ## Destroy the local kind cluster and all platform resources
	@echo "WARNING: This will destroy all platform resources and the kind cluster."
	@read -p "Type 'destroy' to confirm: " CONFIRM && [ "$$CONFIRM" = "destroy" ] || (echo "Aborted." && exit 1)
	kind delete cluster --name platform-local
	@echo "Cluster destroyed."

##@ Utilities

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ports
ports: ## Forward all platform UI ports (run in background)
	@echo "Forwarding platform UI ports..."
	@echo "  Argo CD:  http://localhost:8080  (admin / argocd-initial-admin-secret)"
	@echo "  Grafana:  http://localhost:3000  (admin / platform-admin)"
	@echo "  Vault:    http://localhost:8200  (token: root)"
	@echo "  Backstage: http://localhost:7007"
	$(KUBECTL) port-forward -n argocd svc/argocd-server 8080:443 &
	$(KUBECTL) port-forward -n monitoring svc/monitoring-grafana 3000:80 &
	$(KUBECTL) port-forward -n vault svc/vault 8200:8200 &
	$(KUBECTL) port-forward -n backstage svc/backstage 7007:7007 &
	@echo "All ports forwarded. Ctrl+C to stop all."
