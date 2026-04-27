# ─────────────────────────────────────────────────────────────────────────────
# Project 01 · Hello World — Makefile
#
# Targets:
#   build   build the multi-stage Docker image
#   run     start the hardened container (read-only, non-root, cap-drop)
#   test    E2E checks: HTTP 200, security headers, UID, readonly rootfs
#   perf    k6 smoke test: 50 VUs × 2 min, p95 < 50 ms
#   push    tag + push to registry (set REGISTRY env var)
#   stop    stop and remove the container
#   clean   stop container + remove image
#   logs    tail container logs
#   sh      exec an interactive shell inside the running container
#   size    verify image is under 10 MB (fails the build if not)
#   inspect show uid + attempt a rootfs write (security verification)
#   help    print this table
#
# Variables (override with env or make VAR=value):
#   IMAGE       image name (default: hello-world)
#   TAG         image tag  (default: 0.1.0)
#   CONTAINER   container name (default: hello)
#   HOST_PORT   host port published to container :80 (default: 8080)
#   REGISTRY    registry prefix for `make push`, e.g. ghcr.io/yourname
# ─────────────────────────────────────────────────────────────────────────────

IMAGE      ?= hello-world
TAG        ?= 0.1.0
CONTAINER  ?= hello
HOST_PORT  ?= 8080
BASE_URL   ?= http://localhost:$(HOST_PORT)
REGISTRY   ?= docker.io/yourusername

.DEFAULT_GOAL := help
.PHONY: help build run test perf push stop clean logs sh size inspect

# Auto-generate help from ## comments
help:
	@printf "\nProject 01 · Hello World\n\n"
	@awk 'BEGIN { FS = ":.*##"; printf "%-12s %s\n", "Target", "Description" } \
	     /^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' \
	     $(MAKEFILE_LIST)
	@printf "\nVariables (override with make VAR=value):\n"
	@printf "  IMAGE=%-12s (current: %s)\n" "" "$(IMAGE):$(TAG)"
	@printf "  HOST_PORT=%-8s (current: %s)\n" "" "$(HOST_PORT)"
	@printf "  REGISTRY=%-9s (current: %s)\n\n" "" "$(REGISTRY)"

# ── Build ────────────────────────────────────────────────────────────────────
build: ## Build the multi-stage Docker image
	@printf "▸ building $(IMAGE):$(TAG)\n"
	docker build \
	  --file infra/Dockerfile \
	  --tag  $(IMAGE):$(TAG) \
	  --label "org.opencontainers.image.created=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)" \
	  .
	@printf "\n▸ image size\n"
	@docker images --format '  {{.Repository}}:{{.Tag}}  {{.Size}}' $(IMAGE):$(TAG)
	@printf "\n✔ build complete\n"

# ── Run ──────────────────────────────────────────────────────────────────────
run: ## Start the hardened container on HOST_PORT (default 8080)
	@printf "▸ starting container: $(CONTAINER) on :$(HOST_PORT)\n"
	@docker rm -f $(CONTAINER) 2>/dev/null || true
	docker run -d \
	  --name             $(CONTAINER) \
	  --publish          $(HOST_PORT):80 \
	  --read-only \
	  --tmpfs            /var/cache/nginx:rw,size=16m \
	  --tmpfs            /var/run:rw,size=4m \
	  --cap-drop=ALL \
	  --cap-add=CHOWN \
	  --cap-add=SETUID \
	  --cap-add=SETGID \
	  --cap-add=NET_BIND_SERVICE \
	  --cap-add=DAC_OVERRIDE \
	  --security-opt=no-new-privileges \
	  --restart=unless-stopped \
	  $(IMAGE):$(TAG)
	@printf "\n▸ waiting for readiness"
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
	  if curl -fsS -o /dev/null "$(BASE_URL)/"; then \
	    printf "\n✔ ready — open $(BASE_URL)\n"; exit 0; \
	  fi; \
	  printf "."; sleep 0.4; \
	done; \
	printf "\n✖ not ready after 4 s\n"; docker logs $(CONTAINER); exit 1

# ── Test ─────────────────────────────────────────────────────────────────────
test: ## Run automated E2E checks (curl + docker exec)
	@bash tests/e2e/check.sh "$(BASE_URL)" "$(CONTAINER)"

# ── Perf ─────────────────────────────────────────────────────────────────────
perf: ## 2-minute k6 smoke test (50 VUs, p95 < 50 ms)
	@if command -v k6 >/dev/null 2>&1; then \
	  printf "▸ k6 found on PATH\n"; \
	  BASE_URL="$(BASE_URL)" k6 run tests/k6/smoke.js; \
	else \
	  printf "▸ k6 not on PATH — pulling grafana/k6 container\n"; \
	  docker run --rm -i \
	    --network=host \
	    -e BASE_URL="$(BASE_URL)" \
	    -v "$(CURDIR)/tests/k6:/scripts:ro" \
	    grafana/k6:latest run /scripts/smoke.js; \
	fi

# ── Push ─────────────────────────────────────────────────────────────────────
push: ## Tag and push to REGISTRY (set REGISTRY=ghcr.io/yourname)
	@printf "▸ tagging $(IMAGE):$(TAG) → $(REGISTRY)/$(IMAGE):$(TAG)\n"
	docker tag $(IMAGE):$(TAG) $(REGISTRY)/$(IMAGE):$(TAG)
	@printf "▸ pushing $(REGISTRY)/$(IMAGE):$(TAG)\n"
	docker push $(REGISTRY)/$(IMAGE):$(TAG)
	@printf "✔ pushed\n"
	@printf "\nPull on any machine with:\n"
	@printf "  docker pull $(REGISTRY)/$(IMAGE):$(TAG)\n"

# ── Stop ─────────────────────────────────────────────────────────────────────
stop: ## Stop and remove the container (image kept)
	@docker rm -f $(CONTAINER) 2>/dev/null && printf "✔ container $(CONTAINER) removed\n" || printf "ℹ container $(CONTAINER) not running\n"

# ── Clean ────────────────────────────────────────────────────────────────────
clean: stop ## Stop container + remove image
	@docker rmi -f $(IMAGE):$(TAG) 2>/dev/null && printf "✔ image $(IMAGE):$(TAG) removed\n" || true

# ── Ops helpers ───────────────────────────────────────────────────────────────
logs: ## Tail container logs (Ctrl-C to stop)
	docker logs -f $(CONTAINER)

sh: ## Exec an interactive shell inside the running container
	docker exec -it $(CONTAINER) sh

size: ## Fail (exit 1) if image exceeds 10 MB
	@SIZE_BYTES=$$(docker image inspect $(IMAGE):$(TAG) --format '{{.Size}}'); \
	SIZE_MB=$$(awk -v b="$$SIZE_BYTES" 'BEGIN{printf "%.2f", b/1024/1024}'); \
	printf "image size: $${SIZE_MB} MB\n"; \
	awk -v b="$$SIZE_BYTES" 'BEGIN{ if (b > 10*1024*1024) exit 1 }' \
	  && printf "✔ under 10 MB\n" \
	  || (printf "✖ FAIL: image exceeds 10 MB target\n"; exit 1)

inspect: ## Show UID inside container + prove read-only rootfs
	@printf "▸ identity inside container\n"
	@docker exec $(CONTAINER) id
	@printf "\n▸ attempting write to / (should fail on read-only rootfs)\n"
	@docker exec $(CONTAINER) sh -c 'touch /rw-test 2>&1 && echo "FAIL: write succeeded" || echo "✔ write refused (read-only rootfs confirmed)"'
