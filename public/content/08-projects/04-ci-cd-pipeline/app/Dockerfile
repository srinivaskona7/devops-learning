# syntax=docker/dockerfile:1.6
# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /src

# Cache dependency downloads separately from source compilation.
# Only re-downloads when go.sum changes.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/go/pkg/mod \
    go mod download

COPY . .

# Build a statically linked binary.
# -trimpath removes local file paths from the binary.
# -ldflags injects version from build arg and strips debug info.
ARG VERSION=dev
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /app/server \
      .

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
# gcr.io/distroless/static-debian12 has:
# - no shell, no package manager, no libc
# - only CA certificates and tzdata
# - attack surface: near zero
FROM gcr.io/distroless/static-debian12:nonroot

# nonroot tag sets USER 65532 (nobody) — no explicit USER directive needed.
# WORKDIR is owned by nobody in the distroless image.
WORKDIR /app

COPY --from=builder /app/server /app/server

# Expose the default port. Can be overridden via PORT env var.
EXPOSE 8080

# Health check uses the /healthz endpoint.
# distroless has no shell or wget — use the binary itself with a self-check flag,
# OR rely on Kubernetes readiness/liveness probes (recommended for K8s deployments).
# The HEALTHCHECK below is for docker run / docker-compose usage only.
# For Kubernetes: remove HEALTHCHECK and use httpGet probes in the Pod spec.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/server"]

ENTRYPOINT ["/app/server"]
