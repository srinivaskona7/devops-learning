REGISTRY      ?= ghcr.io
IMAGE_NAME    ?= $(shell git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]')
IMAGE         ?= $(REGISTRY)/$(IMAGE_NAME)
VERSION       ?= $(shell git describe --tags --always --dirty)
PLATFORMS     ?= linux/amd64,linux/arm64
CLUSTER_NAME  ?= ci-local-$(shell date +%s)

.PHONY: all build test scan sign-local push test-integration preview ci-local clean help

all: lint test build scan ## Run all quality gates locally

## ── Build ─────────────────────────────────────────────────────────────────
build: ## Build multi-arch image (local load only)
	docker buildx build \
	  --platform $(PLATFORMS) \
	  --build-arg VERSION=$(VERSION) \
	  --tag $(IMAGE):$(VERSION) \
	  --tag $(IMAGE):dev \
	  --load \
	  app/
	@echo "Built $(IMAGE):$(VERSION)"

build-local: ## Build single-arch image for local testing (fast)
	docker build \
	  --build-arg VERSION=$(VERSION) \
	  --tag $(IMAGE):dev \
	  app/
	@echo "Built $(IMAGE):dev"

## ── Test ──────────────────────────────────────────────────────────────────
test: ## Run unit tests with race detector
	cd app && go test -race -v -coverprofile=coverage.out ./...
	@echo "Coverage report: app/coverage.out"

lint: ## Run golangci-lint
	cd app && golangci-lint run ./...

## ── Security ──────────────────────────────────────────────────────────────
scan: ## Run Trivy vulnerability scan against local image
	@docker image inspect $(IMAGE):dev > /dev/null 2>&1 || $(MAKE) build-local
	trivy image \
	  --severity CRITICAL,HIGH \
	  --exit-code 1 \
	  --ignore-unfixed \
	  $(IMAGE):dev

scan-sbom: ## Generate SBOM for local image
	@docker image inspect $(IMAGE):dev > /dev/null 2>&1 || $(MAKE) build-local
	trivy image \
	  --format spdx-json \
	  --output sbom.spdx.json \
	  $(IMAGE):dev
	@echo "SBOM written to sbom.spdx.json"

sign-local: ## Sign local image with a local cosign key (not keyless)
	@test -f cosign.key || cosign generate-key-pair
	cosign sign --key cosign.key $(IMAGE):dev
	@echo "Signed $(IMAGE):dev with local key"

sign-verify: ## Verify keyless cosign signature (supply IMAGE= env)
	@test -n "$(SIGNED_IMAGE)" || (echo "Set SIGNED_IMAGE=ghcr.io/..." && exit 1)
	cosign verify \
	  --certificate-identity-regexp "https://github.com/$(IMAGE_NAME)/" \
	  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
	  $(SIGNED_IMAGE)

## ── Registry ──────────────────────────────────────────────────────────────
push: ## Build and push multi-arch image to GHCR
	docker buildx build \
	  --platform $(PLATFORMS) \
	  --build-arg VERSION=$(VERSION) \
	  --tag $(IMAGE):$(VERSION) \
	  --push \
	  app/
	@echo "Pushed $(IMAGE):$(VERSION)"

## ── Integration tests ─────────────────────────────────────────────────────
test-integration: build-local ## Spin up kind cluster and run k6 smoke test
	@echo "Creating kind cluster: $(CLUSTER_NAME)"
	kind create cluster \
	  --config infra/kind.yaml \
	  --name $(CLUSTER_NAME) \
	  --wait 60s

	@echo "Loading image into kind..."
	kind load docker-image $(IMAGE):dev \
	  --name $(CLUSTER_NAME)

	@echo "Deploying application..."
	kubectl create namespace integration-test \
	  --context kind-$(CLUSTER_NAME)
	kubectl create deployment cicd-demo \
	  --image=$(IMAGE):dev \
	  --namespace=integration-test \
	  --context kind-$(CLUSTER_NAME)
	kubectl expose deployment cicd-demo \
	  --port=8080 --type=NodePort \
	  --namespace=integration-test \
	  --context kind-$(CLUSTER_NAME)
	kubectl rollout status deployment/cicd-demo \
	  --namespace=integration-test \
	  --context kind-$(CLUSTER_NAME) \
	  --timeout=60s

	@echo "Port-forwarding..."
	kubectl port-forward \
	  svc/cicd-demo 8080:8080 \
	  --namespace=integration-test \
	  --context kind-$(CLUSTER_NAME) &
	sleep 3

	@echo "Smoke test: healthz..."
	curl -sf http://localhost:8080/healthz | jq .
	@echo "Smoke test: ready..."
	curl -sf http://localhost:8080/ready | jq .
	@echo "Smoke test: hello..."
	curl -sf http://localhost:8080/api/hello | jq .

	@echo "Running k6 load test..."
	k6 run tests/k6/smoke.js

	@echo "Cleaning up kind cluster..."
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "Integration tests passed."

## ── Preview environment ────────────────────────────────────────────────────
preview: build-local ## Deploy to local kind cluster as preview
	@test -n "$(PR_NUMBER)" || (echo "Set PR_NUMBER=<number>" && exit 1)
	kind create cluster \
	  --config infra/kind.yaml \
	  --name preview-$(PR_NUMBER) \
	  --wait 60s || true
	kind load docker-image $(IMAGE):dev \
	  --name preview-$(PR_NUMBER)
	infra/preview/deploy.sh $(PR_NUMBER) $(IMAGE):dev
	@echo "Preview running. Delete with: make preview-clean PR_NUMBER=$(PR_NUMBER)"

preview-clean: ## Remove preview kind cluster
	@test -n "$(PR_NUMBER)" || (echo "Set PR_NUMBER=<number>" && exit 1)
	infra/preview/cleanup.sh $(PR_NUMBER) || true
	kind delete cluster --name preview-$(PR_NUMBER) || true

## ── Full local CI simulation ───────────────────────────────────────────────
ci-local: ## Run the full 7-stage pipeline locally using act
	@command -v act >/dev/null 2>&1 || \
	  (echo "Install act: https://github.com/nektos/act" && exit 1)
	act push \
	  --workflows .github/workflows/ci.yml \
	  --secret GITHUB_TOKEN=$$(gh auth token) \
	  --platform ubuntu-latest=catthehacker/ubuntu:act-latest \
	  --bind

## ── Utility ────────────────────────────────────────────────────────────────
clean: ## Remove build artifacts and local images
	docker rmi $(IMAGE):dev $(IMAGE):$(VERSION) 2>/dev/null || true
	rm -f sbom.spdx.json coverage.out cosign.key cosign.pub
	kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true

go-mod: ## Initialize Go module (run once after cloning)
	cd app && go mod tidy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'
