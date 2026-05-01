# Makefile — Security Hardening Lab
# ─────────────────────────────────────────────────────────────────────────────
# All commands for the Security Hardening Lab.
# Run `make help` to see all targets.
#
# Prerequisites:
#   kubectl, helm, trivy, cosign, syft, jq, kube-bench (or docker)
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help scan sign sbom verify-supply-chain \
        apply-policies psa-enable netpol-apply \
        kube-bench falco-start falco-stop falco-logs \
        apply-baseline apply-hardened \
        rbac-check audit-all \
        clean

# ── Variables ──────────────────────────────────────────────────────────────────
IMAGE_REF        ?= ghcr.io/org/secure-app@sha256:a1b2c3d4e5f6
NAMESPACE        ?= production
KYVERNO_VERSION  ?= 3.1.4
FALCO_VERSION    ?= 4.2.0
ESO_VERSION      ?= 0.9.13

# Color codes for output
GREEN  := \033[0;32m
RED    := \033[0;31m
YELLOW := \033[0;33m
NC     := \033[0m   # No Color

# ── Help ───────────────────────────────────────────────────────────────────────
help: ## Show this help
	@echo ""
	@echo "Security Hardening Lab — Available Commands"
	@echo "════════════════════════════════════════════"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
	  {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "  IMAGE_REF=$(IMAGE_REF)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo ""

# ── Supply Chain ───────────────────────────────────────────────────────────────
scan: ## Run Trivy image vulnerability + secret scan
	@echo "$(YELLOW)[scan]$(NC) Scanning image: $(IMAGE_REF)"
	@chmod +x scanners/scan.sh
	@./scanners/scan.sh "$(IMAGE_REF)" scan-results.json
	@echo "$(GREEN)[scan] Complete. Results: scan-results.json$(NC)"

sign: ## Keyless cosign sign image (requires OIDC identity from CI)
	@echo "$(YELLOW)[sign]$(NC) Signing image: $(IMAGE_REF)"
	@chmod +x scanners/cosign-sign-verify.sh
	@./scanners/cosign-sign-verify.sh sign "$(IMAGE_REF)"

verify: ## Verify cosign signature + SBOM attestation
	@echo "$(YELLOW)[verify]$(NC) Verifying image: $(IMAGE_REF)"
	@chmod +x scanners/cosign-sign-verify.sh
	@./scanners/cosign-sign-verify.sh verify-all "$(IMAGE_REF)"

sbom: ## Generate CycloneDX SBOM with syft + upload as cosign attestation
	@echo "$(YELLOW)[sbom]$(NC) Generating SBOM for: $(IMAGE_REF)"
	@chmod +x scanners/syft-sbom.sh
	@./scanners/syft-sbom.sh "$(IMAGE_REF)" sbom-cyclonedx.json

verify-supply-chain: scan verify ## Full supply chain check: scan + verify signature + SBOM
	@echo "$(GREEN)[supply-chain] All checks passed.$(NC)"

# ── Admission Policies ─────────────────────────────────────────────────────────
install-kyverno: ## Install Kyverno admission controller
	@echo "$(YELLOW)[kyverno]$(NC) Installing Kyverno v$(KYVERNO_VERSION)..."
	@helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
	@helm repo update kyverno
	@helm upgrade --install kyverno kyverno/kyverno \
	  --namespace kyverno \
	  --create-namespace \
	  --version "$(KYVERNO_VERSION)" \
	  --set replicaCount=1 \
	  --wait --timeout=5m
	@echo "$(GREEN)[kyverno] Installed.$(NC)"

apply-policies: install-kyverno ## Apply all 5 Kyverno security policies
	@echo "$(YELLOW)[policies]$(NC) Applying Kyverno policies..."
	@kubectl apply -f policies/kyverno/require-non-root.yaml
	@kubectl apply -f policies/kyverno/require-resource-limits.yaml
	@kubectl apply -f policies/kyverno/deny-privilege-escalation.yaml
	@kubectl apply -f policies/kyverno/require-image-digest.yaml
	@kubectl apply -f policies/kyverno/restrict-hostpath.yaml
	@echo "$(GREEN)[policies] 5 policies applied in enforce mode.$(NC)"
	@kubectl get clusterpolicies -o custom-columns='NAME:.metadata.name,MODE:.spec.validationFailureAction,READY:.status.ready'

# ── PSA ───────────────────────────────────────────────────────────────────────
psa-enable: ## Label production namespace for PSA restricted profile
	@echo "$(YELLOW)[psa]$(NC) Labeling namespace $(NAMESPACE) with PSA restricted..."
	@kubectl create namespace $(NAMESPACE) 2>/dev/null || true
	@kubectl label namespace $(NAMESPACE) \
	  pod-security.kubernetes.io/enforce=restricted \
	  pod-security.kubernetes.io/enforce-version=latest \
	  pod-security.kubernetes.io/warn=restricted \
	  pod-security.kubernetes.io/audit=restricted \
	  --overwrite
	@echo "$(GREEN)[psa] Namespace $(NAMESPACE) enforces restricted profile.$(NC)"
	@kubectl get namespace $(NAMESPACE) --show-labels

psa-check: ## Check PSA labels on production namespace
	@kubectl get namespace $(NAMESPACE) \
	  -o jsonpath='{.metadata.labels}' | jq .

# ── NetworkPolicy ─────────────────────────────────────────────────────────────
netpol-apply: ## Apply default-deny + explicit allow NetworkPolicies
	@echo "$(YELLOW)[netpol]$(NC) Applying NetworkPolicies to $(NAMESPACE)..."
	@kubectl apply -f hardened/secure-deployment.yaml
	@echo "$(GREEN)[netpol] Policies applied.$(NC)"
	@kubectl get networkpolicies -n $(NAMESPACE)

netpol-test: ## Test that cross-namespace traffic is blocked
	@echo "$(YELLOW)[netpol-test]$(NC) Testing NetworkPolicy enforcement..."
	@kubectl run netpol-test --image=curlimages/curl:latest \
	  --restart=Never \
	  --namespace=$(NAMESPACE) \
	  --command -- curl -s --max-time 5 http://kube-dns.kube-system:53 || true
	@kubectl delete pod netpol-test --namespace=$(NAMESPACE) 2>/dev/null || true
	@echo "$(GREEN)[netpol-test] Done. Check output above for connection timeout.$(NC)"

# ── RBAC ──────────────────────────────────────────────────────────────────────
apply-rbac: ## Apply hardened RBAC (secure-sa + Role + RoleBinding)
	@echo "$(YELLOW)[rbac]$(NC) Applying hardened RBAC..."
	@kubectl apply -f hardened/secure-rbac.yaml
	@echo "$(GREEN)[rbac] Applied.$(NC)"

rbac-check: ## Verify SA cannot escalate privileges
	@echo "$(YELLOW)[rbac-check]$(NC) Verifying RBAC restrictions..."
	@echo "--- cluster-admin check (should be no):"
	@kubectl auth can-i '*' '*' \
	  --as=system:serviceaccount:$(NAMESPACE):secure-sa || true
	@echo "--- delete pods (should be no):"
	@kubectl auth can-i delete pods \
	  --as=system:serviceaccount:$(NAMESPACE):secure-sa \
	  -n $(NAMESPACE) || true
	@echo "--- get secrets (should be no):"
	@kubectl auth can-i get secrets \
	  --as=system:serviceaccount:$(NAMESPACE):secure-sa \
	  -n $(NAMESPACE) || true
	@echo "--- get configmaps/secure-app-config (should be yes):"
	@kubectl auth can-i get configmaps/secure-app-config \
	  --as=system:serviceaccount:$(NAMESPACE):secure-sa \
	  -n $(NAMESPACE) || true

# ── Deployments ───────────────────────────────────────────────────────────────
apply-baseline: ## Deploy the insecure baseline (for comparison only)
	@echo "$(RED)[WARNING]$(NC) Deploying INSECURE baseline — for lab comparison ONLY"
	@kubectl apply -f baseline/insecure-deployment.yaml
	@kubectl apply -f baseline/insecure-rbac.yaml

apply-hardened: ## Deploy the hardened workload
	@echo "$(YELLOW)[deploy]$(NC) Deploying hardened workload to $(NAMESPACE)..."
	@kubectl apply -f hardened/secure-deployment.yaml
	@kubectl apply -f hardened/secure-rbac.yaml
	@echo "$(GREEN)[deploy] Hardened workload deployed.$(NC)"

# ── kube-bench ────────────────────────────────────────────────────────────────
kube-bench: ## Run CIS Kubernetes Benchmark via kube-bench (target: ≥85% PASS)
	@echo "$(YELLOW)[kube-bench]$(NC) Running CIS Kubernetes Benchmark..."
	@if command -v kube-bench &>/dev/null; then \
	  kube-bench run --targets node,policies,managedservices \
	    --json | jq '.Controls[].tests[].results[] | select(.status=="FAIL") | .test_desc' \
	    | head -20; \
	else \
	  echo "Running kube-bench via Docker..."; \
	  docker run --rm \
	    -v "$(shell pwd)":/host \
	    aquasec/kube-bench:latest \
	    run --targets node,policies \
	    --config-dir /opt/kube-bench/cfg \
	    --config /opt/kube-bench/cfg/config.yaml; \
	fi

# ── Falco ─────────────────────────────────────────────────────────────────────
install-eso: ## Install External Secrets Operator
	@echo "$(YELLOW)[eso]$(NC) Installing External Secrets Operator v$(ESO_VERSION)..."
	@helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
	@helm repo update external-secrets
	@helm upgrade --install external-secrets \
	  external-secrets/external-secrets \
	  --namespace external-secrets \
	  --create-namespace \
	  --version "$(ESO_VERSION)" \
	  --wait --timeout=3m
	@echo "$(GREEN)[eso] Installed.$(NC)"

falco-start: ## Install Falco with custom rules via Helm
	@echo "$(YELLOW)[falco]$(NC) Installing Falco v$(FALCO_VERSION) with custom rules..."
	@helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
	@helm repo update falcosecurity
	@helm upgrade --install falco falcosecurity/falco \
	  --namespace falco \
	  --create-namespace \
	  --version "$(FALCO_VERSION)" \
	  --set driver.kind=ebpf \
	  --set-file customRules."lab_rules\.yaml"=runtime/falco-rules.yaml \
	  --wait --timeout=5m
	@echo "$(GREEN)[falco] Installed. Custom rules loaded.$(NC)"
	@kubectl get pods -n falco

falco-stop: ## Uninstall Falco
	@helm uninstall falco -n falco 2>/dev/null || true
	@kubectl delete namespace falco 2>/dev/null || true
	@echo "$(GREEN)[falco] Uninstalled.$(NC)"

falco-logs: ## Stream Falco alerts
	@echo "$(YELLOW)[falco]$(NC) Streaming alerts (Ctrl+C to stop)..."
	@kubectl logs -n falco -l app.kubernetes.io/name=falco \
	  --follow --since=1m

falco-test: ## Trigger a test Falco alert (exec in container)
	@echo "$(YELLOW)[falco-test]$(NC) Triggering exec_in_container rule..."
	@POD=$$(kubectl get pods -n $(NAMESPACE) -l app=secure-app \
	  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [[ -n "$$POD" ]]; then \
	  echo "Exec into pod $$POD — watch Falco logs"; \
	  kubectl exec -n $(NAMESPACE) "$$POD" -- /bin/sh -c "id" 2>/dev/null || true; \
	else \
	  echo "No secure-app pod found. Deploy with: make apply-hardened"; \
	fi

# ── Full Audit ────────────────────────────────────────────────────────────────
audit-all: ## Run the complete PASS/FAIL security audit matrix
	@echo "$(YELLOW)[audit]$(NC) Running full security audit..."
	@chmod +x tests/audit.sh
	@./tests/audit.sh

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean: ## Remove lab artifacts (scan results, SBOMs)
	@rm -f scan-results.json sbom-cyclonedx.json
	@echo "$(GREEN)[clean] Artifacts removed.$(NC)"

clean-all: ## Tear down all lab resources from the cluster
	@echo "$(RED)[clean-all]$(NC) Removing all lab resources..."
	@kubectl delete -f hardened/secure-deployment.yaml 2>/dev/null || true
	@kubectl delete -f hardened/secure-rbac.yaml 2>/dev/null || true
	@kubectl delete -f baseline/insecure-deployment.yaml 2>/dev/null || true
	@kubectl delete -f baseline/insecure-rbac.yaml 2>/dev/null || true
	@kubectl delete -f policies/kyverno/ 2>/dev/null || true
	@helm uninstall falco -n falco 2>/dev/null || true
	@helm uninstall kyverno -n kyverno 2>/dev/null || true
	@kubectl delete namespace production insecure-workloads falco kyverno 2>/dev/null || true
	@echo "$(GREEN)[clean-all] Done.$(NC)"
