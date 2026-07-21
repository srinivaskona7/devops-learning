CLUSTER  := obs-demo-cluster
NS       := obs-demo
APP_IMG  := obs-demo:1.0.0
GRAFANA_PORT := 3000
APP_PORT     := 8000
PROM_PORT    := 9090
LOKI_PORT    := 3100
TEMPO_PORT   := 3200

HELM_PROM_VERSION  := 58.3.1
HELM_LOKI_VERSION  := 6.6.2
HELM_TEMPO_VERSION := 1.9.0

.DEFAULT_GOAL := help

# ── Help ───────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "  Project 05 · Observability Stack"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make up            Spin up kind cluster + install full stack"
	@echo "  make build         Build obs-demo Docker image"
	@echo "  make deploy        Apply k8s manifests (after make up)"
	@echo "  make demo-fast     Run 200 fast requests to drive Rate panel"
	@echo "  make demo-slow     Run 20 slow requests to drive Duration panel"
	@echo "  make demo-error    Run 100 flaky requests to drive Error panel"
	@echo "  make demo-trace    Single /slow request + print trace_id"
	@echo "  make demo-cpu      Run 50 cpu requests to drive Saturation panel"
	@echo "  make perf          k6 smoke test (all endpoints, 3m)"
	@echo "  make port-forward  Forward Grafana/Prometheus/Loki/Tempo locally"
	@echo "  make logs          Tail obs-demo logs (structured JSON)"
	@echo "  make test          Run all demo scenarios sequentially"
	@echo "  make down          Destroy kind cluster"
	@echo ""

# ── Cluster bootstrap ─────────────────────────────────────────────────────
.PHONY: up
up: cluster-create helm-repos build load-image namespace deploy install-prom install-loki install-tempo wait-stack port-forward
	@echo ""
	@echo "  Stack is up!"
	@echo "  Grafana  → http://localhost:$(GRAFANA_PORT)  (admin / obs-demo-secret)"
	@echo "  App      → http://localhost:$(APP_PORT)"
	@echo "  Prom     → http://localhost:$(PROM_PORT)"
	@echo "  Loki     → http://localhost:$(LOKI_PORT)"
	@echo "  Tempo    → http://localhost:$(TEMPO_PORT)"
	@echo ""
	@echo "  Run 'make demo-trace' to capture your first correlated trace."

.PHONY: cluster-create
cluster-create:
	@echo "── Creating kind cluster: $(CLUSTER)"
	kind get clusters 2>/dev/null | grep -q $(CLUSTER) || \
	  kind create cluster --name $(CLUSTER) \
	    --config - <<'EOF'\
	kind: Cluster\
	apiVersion: kind.x-k8s.io/v1alpha4\
	nodes:\
	  - role: control-plane\
	    kubeadmConfigPatches:\
	      - |\
	        kind: InitConfiguration\
	        nodeRegistration:\
	          kubeletExtraArgs:\
	            node-labels: "ingress-ready=true"\
	EOF

.PHONY: helm-repos
helm-repos:
	@echo "── Adding Helm repos"
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
	helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
	helm repo update

.PHONY: build
build:
	@echo "── Building $(APP_IMG)"
	docker build -t $(APP_IMG) ./app

.PHONY: load-image
load-image:
	@echo "── Loading $(APP_IMG) into kind"
	kind load docker-image $(APP_IMG) --name $(CLUSTER)

.PHONY: namespace
namespace:
	@echo "── Creating namespace $(NS)"
	kubectl get namespace $(NS) 2>/dev/null || kubectl create namespace $(NS)

.PHONY: deploy
deploy:
	@echo "── Applying k8s manifests"
	kubectl apply -f infra/k8s/configmap-otel.yaml
	kubectl apply -f infra/k8s/deployment.yaml
	kubectl apply -f infra/k8s/service.yaml
	kubectl apply -f infra/k8s/servicemonitor.yaml
	kubectl rollout status deployment/obs-demo -n $(NS)

.PHONY: install-prom
install-prom:
	@echo "── Installing kube-prometheus-stack"
	helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
	  --namespace $(NS) \
	  --version $(HELM_PROM_VERSION) \
	  -f infra/helm-values/kube-prom-stack.yaml \
	  --wait --timeout 5m

.PHONY: install-loki
install-loki:
	@echo "── Installing Loki"
	helm upgrade --install loki grafana/loki \
	  --namespace $(NS) \
	  --version $(HELM_LOKI_VERSION) \
	  -f infra/helm-values/loki.yaml \
	  --wait --timeout 5m

.PHONY: install-tempo
install-tempo:
	@echo "── Installing Tempo"
	helm upgrade --install tempo grafana/tempo \
	  --namespace $(NS) \
	  --version $(HELM_TEMPO_VERSION) \
	  -f infra/helm-values/tempo.yaml \
	  --wait --timeout 5m

.PHONY: wait-stack
wait-stack:
	@echo "── Waiting for all pods to be Running"
	kubectl wait --for=condition=ready pod --all -n $(NS) --timeout=300s

# ── Port forwarding ───────────────────────────────────────────────────────
.PHONY: port-forward
port-forward:
	@echo "── Starting port-forwards in background"
	kubectl port-forward -n $(NS) svc/kube-prom-stack-grafana $(GRAFANA_PORT):80 &
	kubectl port-forward -n $(NS) svc/prometheus-operated $(PROM_PORT):9090 &
	kubectl port-forward -n $(NS) svc/loki $(LOKI_PORT):3100 &
	kubectl port-forward -n $(NS) svc/tempo $(TEMPO_PORT):3100 &
	kubectl port-forward -n $(NS) svc/obs-demo $(APP_PORT):80 &
	sleep 2
	@echo "  Port-forwards active (run 'pkill -f kubectl.*port-forward' to stop)"

# ── Demo scenarios ────────────────────────────────────────────────────────
.PHONY: demo-fast
demo-fast:
	@echo "── Firing 200 fast requests (drives Rate panel)"
	for i in $$(seq 200); do curl -s http://localhost:$(APP_PORT)/fast > /dev/null; done
	@echo "  Done. Open Grafana → Four Golden Signals → Request Rate"

.PHONY: demo-slow
demo-slow:
	@echo "── Firing 20 slow requests (drives Duration panel)"
	for i in $$(seq 20); do curl -s http://localhost:$(APP_PORT)/slow; echo ""; done
	@echo "  Done. Open Grafana → Four Golden Signals → Latency p95"

.PHONY: demo-error
demo-error:
	@echo "── Firing 100 flaky requests ~30% will 500 (drives Error panel)"
	for i in $$(seq 100); do curl -s -o /dev/null -w "%{http_code} " http://localhost:$(APP_PORT)/flaky; done
	@echo ""
	@echo "  Done. Open Grafana → Four Golden Signals → Error Rate"

.PHONY: demo-cpu
demo-cpu:
	@echo "── Firing 50 cpu-burn requests (drives Saturation panel)"
	for i in $$(seq 50); do curl -s http://localhost:$(APP_PORT)/cpu > /dev/null; done
	@echo "  Done. Open Grafana → Four Golden Signals → Saturation"

.PHONY: demo-trace
demo-trace:
	@echo "── Single /slow request → extract trace_id from logs"
	curl -s http://localhost:$(APP_PORT)/slow | jq .
	@sleep 3
	@echo ""
	@echo "Captured trace_id from logs:"
	@kubectl -n $(NS) logs deploy/obs-demo --since=15s 2>/dev/null \
	  | grep -oP 'trace_id=\K[a-f0-9]{32}' | tail -1 || \
	  kubectl -n $(NS) logs deploy/obs-demo --since=15s 2>/dev/null \
	  | grep -oP '"otelTraceID":"?\K[a-f0-9]{32}' | tail -1
	@echo ""
	@echo "  1. Open Grafana → Four Golden Signals"
	@echo "  2. Click a diamond exemplar on the latency panel"
	@echo "  3. Click 'View in Tempo' → verify span name = slow-handler"
	@echo "  4. Click 'Logs for this span' → verify Loki shows same trace_id"

# ── Observability verification ────────────────────────────────────────────
.PHONY: check-metrics
check-metrics:
	@echo "── Prometheus query: request rate"
	curl -s "http://localhost:$(PROM_PORT)/api/v1/query?query=sum(rate(demo_requests_total[5m]))" | jq '.data.result'

.PHONY: check-logs
check-logs:
	@echo "── Loki query: recent obs-demo logs"
	curl -sG "http://localhost:$(LOKI_PORT)/loki/api/v1/query_range" \
	  --data-urlencode 'query={service_name="obs-demo"}' \
	  --data-urlencode 'limit=5' | jq '.data.result[].values[][1]' 2>/dev/null | head -5

.PHONY: check-traces
check-traces:
	@echo "── Tempo: search for obs-demo traces"
	curl -s "http://localhost:$(TEMPO_PORT)/api/search?service.name=obs-demo&limit=3" | jq '.traces[].rootTraceName'

# ── Tests ─────────────────────────────────────────────────────────────────
.PHONY: test
test: demo-fast demo-error demo-slow demo-cpu
	@echo "── All demo scenarios complete"
	@echo "   Verify in Grafana: http://localhost:$(GRAFANA_PORT)"

.PHONY: perf
perf:
	@echo "── k6 smoke test (all endpoints, ~3m)"
	k6 run --env BASE_URL=http://localhost:$(APP_PORT) tests/k6/smoke.js

# ── Logs ──────────────────────────────────────────────────────────────────
.PHONY: logs
logs:
	kubectl -n $(NS) logs -l app=obs-demo -f --prefix=true

# ── Teardown ──────────────────────────────────────────────────────────────
.PHONY: down
down:
	@echo "── Destroying kind cluster $(CLUSTER)"
	pkill -f "kubectl.*port-forward" 2>/dev/null || true
	kind delete cluster --name $(CLUSTER)
	@echo "  Cluster deleted."
