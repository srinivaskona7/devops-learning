SERVICE   := ${{values.name}}
TEAM      := ${{values.team}}
SLO_TIER  := ${{values.slo_tier}}
PORT      := ${{values.port}}
REGISTRY  := ghcr.io/vantapay
IMAGE     := $(REGISTRY)/$(SERVICE)
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

.DEFAULT_GOAL := help

##@ Development

.PHONY: build
build: ## Build the Go binary locally
	go build -ldflags="-X main.version=$(VERSION)" -o bin/$(SERVICE) ./app/...

.PHONY: test
test: ## Run unit tests with race detector
	go test -race -count=1 -timeout=60s ./app/...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	go test -race -coverprofile=coverage.out -covermode=atomic ./app/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

.PHONY: lint
lint: ## Run golangci-lint
	@which golangci-lint > /dev/null || (echo "Install golangci-lint: https://golangci-lint.run/usage/install/" && exit 1)
	golangci-lint run ./...

.PHONY: run
run: ## Run the service locally
	SERVICE_NAME=$(SERVICE) SLO_TIER=$(SLO_TIER) PORT=$(PORT) \
	OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317 \
	go run ./app/...

##@ Container

.PHONY: docker-build
docker-build: ## Build Docker image
	docker build \
		--build-arg VERSION=$(VERSION) \
		--tag $(IMAGE):$(VERSION) \
		--tag $(IMAGE):latest \
		--label "org.opencontainers.image.revision=$(shell git rev-parse HEAD)" \
		.

.PHONY: docker-push
docker-push: docker-build ## Build and push Docker image to registry
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

.PHONY: docker-scan
docker-scan: docker-build ## Scan image for vulnerabilities (requires trivy)
	@which trivy > /dev/null || (echo "Install trivy: https://trivy.dev" && exit 1)
	trivy image --severity CRITICAL,HIGH --exit-code 1 $(IMAGE):$(VERSION)

.PHONY: docker-sign
docker-sign: ## Sign image with Cosign (keyless — requires OIDC token)
	@which cosign > /dev/null || (echo "Install cosign: https://docs.sigstore.dev/cosign/installation/" && exit 1)
	cosign sign --yes $(IMAGE):$(VERSION)

##@ Deployment

.PHONY: deploy
deploy: ## Deploy to cluster via GitOps (update image tag in k8s manifests)
	@echo "Updating image tag to $(VERSION) in k8s/rollout.yaml"
	sed -i.bak 's|$(IMAGE):.*|$(IMAGE):$(VERSION)|g' k8s/rollout.yaml
	rm -f k8s/rollout.yaml.bak
	@echo "Commit and push this change to trigger Argo CD sync"

.PHONY: status
status: ## Show Argo Rollouts status
	kubectl argo rollouts get rollout $(SERVICE) -n $(TEAM) --watch

.PHONY: promote
promote: ## Manually promote canary (use with caution)
	kubectl argo rollouts promote $(SERVICE) -n $(TEAM)

.PHONY: rollback
rollback: ## Abort canary and rollback to stable
	kubectl argo rollouts abort $(SERVICE) -n $(TEAM)
	kubectl argo rollouts undo $(SERVICE) -n $(TEAM)

##@ Observability

.PHONY: logs
logs: ## Stream logs from the service (structured JSON)
	kubectl logs -n $(TEAM) -l app=$(SERVICE) -f --all-containers

.PHONY: traces
traces: ## Open Grafana traces view in browser
	open "https://grafana.vantapay.io/explore?left=%7B%22queries%22:%5B%7B%22datasource%22:%22tempo%22,%22queryType%22:%22traceql%22,%22query%22:%22%7B%20resource.service.name%20%3D%20%5C%22$(SERVICE)%5C%22%20%7D%22%7D%5D%7D"

.PHONY: dashboard
dashboard: ## Open Grafana service dashboard in browser
	open "https://grafana.vantapay.io/d/platform-$(SERVICE)"

##@ Reliability

.PHONY: chaos-drill
chaos-drill: ## Run a chaos drill against this service
	@echo "Running chaos drill for $(SERVICE) (SLO tier: $(SLO_TIER))"
	@echo "1. Starting k6 load (500 VUs, 10m)..."
	k6 run --env SERVICE=$(SERVICE) --env PORT=$(PORT) tests/k6/load.js &
	K6_PID=$$!
	@echo "2. Applying chaos experiments..."
	kubectl apply -f ../../chaos/pod-kill-experiment.yaml -n chaos-mesh
	sleep 60
	kubectl apply -f ../../chaos/network-delay-experiment.yaml -n chaos-mesh
	sleep 60
	kubectl apply -f ../../chaos/cpu-stress-experiment.yaml -n chaos-mesh
	wait $$K6_PID
	@echo "3. Cleaning up chaos experiments..."
	kubectl delete -f ../../chaos/pod-kill-experiment.yaml -n chaos-mesh --ignore-not-found
	kubectl delete -f ../../chaos/network-delay-experiment.yaml -n chaos-mesh --ignore-not-found
	kubectl delete -f ../../chaos/cpu-stress-experiment.yaml -n chaos-mesh --ignore-not-found
	@echo "Chaos drill complete. Check Grafana for results."

.PHONY: perf
perf: ## Run k6 load test
	@which k6 > /dev/null || (echo "Install k6: https://k6.io/docs/getting-started/installation" && exit 1)
	k6 run --env SERVICE_URL=http://localhost:$(PORT) tests/k6/load.js

##@ Security

.PHONY: audit
audit: ## Run security audit (image scan + policy report + secret check)
	@echo "=== Image scan ==="
	trivy image $(IMAGE):latest
	@echo "=== Kyverno policy report ==="
	kubectl get policyreport -n $(TEAM) -o wide
	@echo "=== ExternalSecret sync status ==="
	kubectl get externalsecret -n $(TEAM) $(SERVICE)-secrets -o jsonpath='{.status.conditions}'

##@ Utilities

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf bin/ coverage.out coverage.html
