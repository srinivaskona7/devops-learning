# Project 03 — GitOps with Argo CD
# Targets: cluster-up bootstrap sync drift-demo promote-to-prod rollback perf down

CLUSTER_NAME    ?= gitops-lab
CONTEXT         ?= kind-$(CLUSTER_NAME)
REPO_URL        ?= https://github.com/YOUR-ORG/Devops-learning
ARGOCD_PASSWORD ?= ArgoCD@Lab123!
ARGOCD_NS       ?= argocd
PROD_NS         ?= api-prod
STAGING_NS      ?= api-staging
API_SVC         ?= url-shortener-api
K6_SCRIPT       := tests/k6/smoke.js
IMAGE_REPO      ?= ghcr.io/YOUR-ORG/url-shortener-api

# Colours
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m

.PHONY: cluster-up cluster-info bootstrap port-forward sync \
        drift-demo promote-to-prod rollback perf \
        status clean-apps down help

## ─── Cluster lifecycle ────────────────────────────────────────────────────────

cluster-up: ## Create the 3-node kind cluster
	@echo "$(YELLOW)▶ Creating kind cluster: $(CLUSTER_NAME)$(NC)"
	kind create cluster --name $(CLUSTER_NAME) \
	  --config infra/kind-config.yaml \
	  --image kindest/node:v1.31.0
	kubectl config use-context $(CONTEXT)
	kubectl wait node --all --for=condition=Ready --timeout=120s
	@echo "$(GREEN)✔ Cluster ready: $(CLUSTER_NAME)$(NC)"
	@kubectl get nodes

cluster-info: ## Show cluster details
	kubectl cluster-info --context $(CONTEXT)
	kubectl get nodes -o wide

down: ## Delete the kind cluster (destroys all data)
	@echo "$(YELLOW)▶ Deleting kind cluster: $(CLUSTER_NAME)$(NC)"
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)✔ Cluster deleted$(NC)"

## ─── Argo CD bootstrap ───────────────────────────────────────────────────────

bootstrap: ## Install Argo CD, set admin password, register repo
	@echo "$(YELLOW)▶ Bootstrapping Argo CD...$(NC)"
	REPO_URL=$(REPO_URL) \
	ARGOCD_PASSWORD=$(ARGOCD_PASSWORD) \
	CONTEXT=$(CONTEXT) \
	bash infra/argocd/bootstrap.sh
	@echo "$(GREEN)✔ Bootstrap complete$(NC)"

port-forward: ## Forward Argo CD UI to localhost:8080 (run in background)
	@echo "$(YELLOW)▶ Port-forwarding argocd-server → localhost:8080$(NC)"
	@pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
	kubectl -n $(ARGOCD_NS) port-forward svc/argocd-server 8080:443 &
	@echo "$(GREEN)✔ UI: https://localhost:8080$(NC)"

## ─── App deployment ──────────────────────────────────────────────────────────

sync: ## Apply root app and force-sync all environments
	@echo "$(YELLOW)▶ Applying root app-of-apps...$(NC)"
	@echo "  → Edit infra/argocd/app-of-apps.yaml first and set repoURL=$(REPO_URL)"
	kubectl apply -f infra/argocd/app-of-apps.yaml
	@echo "$(YELLOW)▶ Waiting for root-app to sync...$(NC)"
	argocd app wait root-app --sync --health --timeout 120 --insecure 2>/dev/null || true
	@echo "$(YELLOW)▶ Syncing child apps...$(NC)"
	argocd app sync api-dev api-staging api-prod --prune --insecure 2>/dev/null || \
	  echo "  (argocd CLI not logged in — use: argocd login localhost:8080 --username admin --insecure)"
	@echo "$(GREEN)✔ Sync triggered$(NC)"

status: ## Show sync and health status of all Argo CD apps
	@kubectl -n $(ARGOCD_NS) get applications \
	  -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL"

## ─── Drift demo ──────────────────────────────────────────────────────────────

drift-demo: ## Introduce drift in api-prod, measure auto-heal time
	@echo "$(YELLOW)▶ Starting drift demo on namespace: $(PROD_NS)$(NC)"
	bash tests/e2e/drift-and-heal.sh $(PROD_NS) $(API_SVC)

## ─── GitOps deploy workflow ──────────────────────────────────────────────────

promote-to-prod: ## Bump prod image tag to v1.1.0 via a git commit
	@echo "$(YELLOW)▶ Promoting to prod: bumping image tag to v1.1.0$(NC)"
	@CURRENT=$$(grep 'newTag' k8s/overlays/prod/kustomization.yaml | awk '{print $$2}' | tr -d '"'); \
	  echo "  Current tag: $$CURRENT → v1.1.0"; \
	  sed -i '' 's/newTag: "'"$$CURRENT"'"/newTag: "v1.1.0"/' \
	    k8s/overlays/prod/kustomization.yaml; \
	  git add k8s/overlays/prod/kustomization.yaml; \
	  git commit -m "deploy(prod): promote url-shortener to v1.1.0"; \
	  git push origin main
	@echo "$(GREEN)✔ Commit pushed — Argo CD will converge within 3 min$(NC)"
	@echo "  Watch: argocd app get api-prod --watch"

rollback: ## Revert last prod commit → cluster rolls back automatically
	@echo "$(YELLOW)▶ Rolling back: reverting last commit on prod overlay$(NC)"
	@git revert HEAD --no-edit
	@git push origin main
	@echo "$(GREEN)✔ Revert pushed — Argo CD will converge to previous image tag$(NC)"
	@echo "  Watch: kubectl -n $(PROD_NS) rollout status deploy/$(API_SVC)"

## ─── Performance test ────────────────────────────────────────────────────────

perf: ## Run k6 smoke test against api-prod (200 VUs, 2 min)
	@echo "$(YELLOW)▶ Starting k6 perf test$(NC)"
	@echo "  Make sure api-prod is accessible. For kind:"
	@echo "  kubectl -n $(PROD_NS) port-forward svc/$(API_SVC) 8090:80 &"
	@kubectl -n $(PROD_NS) port-forward svc/$(API_SVC) 8090:80 & \
	  PF_PID=$$!; \
	  sleep 2; \
	  k6 run $(K6_SCRIPT); \
	  kill $$PF_PID 2>/dev/null || true

## ─── Cleanup ────────────────────────────────────────────────────────────────

clean-apps: ## Delete all Argo CD Application CRDs (keeps cluster running)
	@echo "$(YELLOW)▶ Deleting Argo CD applications...$(NC)"
	kubectl -n $(ARGOCD_NS) delete application root-app api-dev api-staging api-prod \
	  --ignore-not-found=true
	@echo "$(GREEN)✔ Applications deleted$(NC)"

## ─── Help ────────────────────────────────────────────────────────────────────

help: ## Show this help
	@echo ""
	@echo "  Project 03 — GitOps with Argo CD"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

.DEFAULT_GOAL := help
