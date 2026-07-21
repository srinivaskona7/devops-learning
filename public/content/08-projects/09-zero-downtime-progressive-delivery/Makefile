# ═══════════════════════════════════════════════════════════════════════════════
# Makefile — Project 09 · Zero-Downtime Progressive Delivery
#
# All commands target a local kind cluster. Cloud targets are marked optional.
# ═══════════════════════════════════════════════════════════════════════════════

CLUSTER_NAME   := progressive-lab
NAMESPACE      := progressive
APP            := demo-app
IMAGE_REPO     := localhost:5001/demo-app
IMAGE_V1       := $(IMAGE_REPO):v1
IMAGE_V2       := $(IMAGE_REPO):v2
IMAGE_V2_BAD   := $(IMAGE_REPO):v2-bad
K6_BASE_URL    ?= http://localhost:8080
RESULTS_DIR    := tests/k6/results

.PHONY: help up down \
        build-v1 build-v2 build-v2-bad push-v1 push-v2 push-v2-bad \
        deploy-v1 canary-v2 bluegreen-v2 bad-deploy \
        rollback promote \
        load-during verify \
        watch-rollout watch-metrics \
        port-forward port-forward-prom \
        prereqs

# ── Default target ────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Project 09 — Zero-Downtime Progressive Delivery"
	@echo ""
	@echo "  make up              Bootstrap cluster + all control planes"
	@echo "  make deploy-v1       Deploy initial v1 (rolling, 5-step manual)"
	@echo "  make canary-v2       Start automated canary: v1→v2 with SLO gates"
	@echo "  make bluegreen-v2    Start blue-green deploy (manual promotion)"
	@echo "  make bad-deploy      Deploy v2 with bad-weight=0.30 (triggers rollback)"
	@echo "  make load-during     Run 10-min k6 load test covering deploy window"
	@echo "  make rollback        Force immediate rollback to stable"
	@echo "  make promote         Manually promote canary to 100%"
	@echo "  make verify          Parse k6 results → PASS/FAIL zero-downtime check"
	@echo "  make watch-rollout   Stream rollout progress in real time"
	@echo "  make watch-metrics   Stream Prometheus success-rate + p95 every 5s"
	@echo "  make down            Tear down cluster"
	@echo ""

# ── Prerequisites check ───────────────────────────────────────────────────────
prereqs:
	@echo "Checking prerequisites..."
	@command -v kind         >/dev/null 2>&1 || (echo "MISSING: kind"          && exit 1)
	@command -v kubectl      >/dev/null 2>&1 || (echo "MISSING: kubectl"       && exit 1)
	@command -v helm         >/dev/null 2>&1 || (echo "MISSING: helm"          && exit 1)
	@command -v istioctl     >/dev/null 2>&1 || (echo "MISSING: istioctl"      && exit 1)
	@command -v k6           >/dev/null 2>&1 || (echo "MISSING: k6"            && exit 1)
	@command -v jq           >/dev/null 2>&1 || (echo "MISSING: jq"            && exit 1)
	@echo "All prerequisites present."

# ── Cluster bootstrap ─────────────────────────────────────────────────────────
up: prereqs
	@echo "── Creating kind cluster: $(CLUSTER_NAME) ──────────────────────────────"
	kind create cluster --name $(CLUSTER_NAME) --wait 120s || true

	@echo "── Starting local registry ──────────────────────────────────────────────"
	docker run -d -p 5001:5000 --name kind-registry --restart=always registry:2 2>/dev/null || true
	docker network connect kind kind-registry 2>/dev/null || true

	@echo "── Installing Istio (minimal profile) ───────────────────────────────────"
	istioctl install --set profile=minimal --skip-confirmation
	kubectl label namespace default istio-injection=enabled --overwrite

	@echo "── Installing Prometheus Operator (kube-prometheus-stack) ───────────────"
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
	helm repo update
	kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	helm -n monitoring upgrade --install kps prometheus-community/kube-prometheus-stack \
	  --version 62.6.0 \
	  --set grafana.adminPassword=admin \
	  --set prometheus.prometheusSpec.retention=1h \
	  --wait --timeout 10m

	@echo "── Installing Argo Rollouts ─────────────────────────────────────────────"
	kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm repo update
	helm -n argo-rollouts upgrade --install argo-rollouts argo/argo-rollouts \
	  --set dashboard.enabled=true \
	  --wait

	@echo "── Installing Flagger ───────────────────────────────────────────────────"
	helm repo add flagger https://flagger.app --force-update
	helm repo update
	helm -n istio-system upgrade --install flagger flagger/flagger \
	  --set meshProvider=istio \
	  --set metricsServer=http://prometheus-operated.monitoring.svc.cluster.local:9090 \
	  --wait

	@echo "── Creating progressive namespace ───────────────────────────────────────"
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label namespace $(NAMESPACE) istio-injection=enabled --overwrite

	@echo "── Applying Prometheus rules + ServiceMonitor ────────────────────────────"
	kubectl apply -f infra/prometheus/servicemonitor.yaml
	kubectl apply -f infra/prometheus/recording-rules.yaml

	@echo "── Applying Istio DestinationRule + VirtualService ─────────────────────"
	kubectl apply -f infra/istio/destination-rule.yaml
	kubectl apply -f infra/istio/virtual-service.yaml

	@echo "── Applying Argo Rollouts AnalysisTemplate ──────────────────────────────"
	kubectl apply -f infra/argo-rollouts/analysis-template.yaml

	@echo ""
	@echo "  Stack is up. Run 'make deploy-v1' to start."
	@echo ""

# ── Image builds ──────────────────────────────────────────────────────────────
build-v1:
	docker build -t $(IMAGE_V1) --build-arg VERSION=v1 app/

build-v2:
	docker build -t $(IMAGE_V2) --build-arg VERSION=v2 app/

build-v2-bad:
	docker build -t $(IMAGE_V2_BAD) --build-arg VERSION=v2 app/

push-v1: build-v1
	docker push $(IMAGE_V1)

push-v2: build-v2
	docker push $(IMAGE_V2)

push-v2-bad: build-v2-bad
	docker push $(IMAGE_V2_BAD)

# ── Deployments ───────────────────────────────────────────────────────────────
deploy-v1: push-v1
	@echo "── Deploying v1 (initial Rollout, 5-step manual) ────────────────────────"
	kubectl -n $(NAMESPACE) apply -f infra/argo-rollouts/rollout-v1.yaml
	kubectl -n $(NAMESPACE) rollout status deployment/$(APP) --timeout=3m || true
	@echo "  v1 deployed. Watch: make watch-rollout"

canary-v2: push-v2
	@echo "── Starting automated canary: v1→v2 with SLO gates ─────────────────────"
	kubectl -n $(NAMESPACE) apply -f infra/argo-rollouts/rollout-canary.yaml
	@echo "  Canary started. Watch: make watch-rollout"
	@echo "  Run load test in parallel: make load-during"

bluegreen-v2: push-v2
	@echo "── Starting blue-green deploy (manual promotion) ────────────────────────"
	kubectl -n $(NAMESPACE) apply -f infra/argo-rollouts/rollout-bluegreen.yaml
	@echo "  Blue-green deploy in progress. Green is ready when:"
	@echo "    kubectl argo rollouts get rollout demo-app-bluegreen -n $(NAMESPACE)"
	@echo "  Promote with: make promote"

bad-deploy: build-v2-bad push-v2-bad
	@echo "── Deploying BAD v2 (bad-weight=0.30) — will auto-rollback ─────────────"
	# Patch the running canary rollout to inject fault into v2 pods.
	kubectl -n $(NAMESPACE) patch rollout demo-app-canary \
	  --type=json \
	  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/1/value","value":"0.30"}]'
	@echo "  Bad deploy started. Watch rollback: make watch-rollout"
	@echo "  Run load test: make load-during"

# ── Rollout control ───────────────────────────────────────────────────────────
rollback:
	@echo "── Triggering immediate rollback ────────────────────────────────────────"
	kubectl argo rollouts abort demo-app-canary -n $(NAMESPACE) 2>/dev/null || \
	  kubectl argo rollouts undo demo-app-canary -n $(NAMESPACE)
	@echo "  Rolled back to stable."

promote:
	@echo "── Promoting canary to 100% ─────────────────────────────────────────────"
	kubectl argo rollouts promote demo-app-canary -n $(NAMESPACE)

# ── Load testing ─────────────────────────────────────────────────────────────
load-during:
	@echo "── Running 10-min k6 load test (covers deploy window) ──────────────────"
	mkdir -p $(RESULTS_DIR)
	k6 run \
	  --env BASE_URL=$(K6_BASE_URL) \
	  --out json=$(RESULTS_DIR)/raw.json \
	  tests/k6/during-deploy.js 2>&1 | tee $(RESULTS_DIR)/k6.log
	@echo "  Results saved to $(RESULTS_DIR)/summary.json"

verify:
	@echo "── Verifying zero-downtime criteria ─────────────────────────────────────"
	bash tests/verify-zero-downtime.sh

# ── Observability helpers ─────────────────────────────────────────────────────
watch-rollout:
	kubectl argo rollouts get rollout demo-app-canary -n $(NAMESPACE) --watch

watch-metrics:
	@echo "── Streaming Prometheus metrics (Ctrl-C to stop) ────────────────────────"
	@while true; do \
	  echo ""; \
	  echo "$$(date +'%H:%M:%S')"; \
	  kubectl -n monitoring exec -it $$(kubectl -n monitoring get pod \
	    -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}') \
	    -- wget -qO- 'http://localhost:9090/api/v1/query?query=job:http_requests:success_rate2m' \
	    | jq -r '.data.result[] | "\(.metric.kubernetes_service_name): \(.value[1] | tonumber * 100 | floor)%"'; \
	  sleep 5; \
	done

port-forward:
	kubectl -n $(NAMESPACE) port-forward svc/$(APP) 8080:8080

port-forward-prom:
	kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090

# ── Tear down ─────────────────────────────────────────────────────────────────
down:
	@echo "── Deleting kind cluster ────────────────────────────────────────────────"
	kind delete cluster --name $(CLUSTER_NAME)
	docker rm -f kind-registry 2>/dev/null || true
	@echo "  Cluster deleted."
