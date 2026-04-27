# Multi-stage build — platform golden path
# Stage 1: build (Go)
# Stage 2: minimal runtime (distroless)

# ── Build stage ───────────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Cache dependencies separately from source
COPY app/go.mod app/go.sum ./
RUN go mod download && go mod verify

# Build
COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${VERSION:-dev} -X main.buildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o /app/server \
    ./...

# ── Runtime stage ─────────────────────────────────────────────────────────────
# distroless: no shell, no package manager, minimal attack surface
# Contains: ca-certificates, /etc/passwd (for non-root user), tzdata
FROM gcr.io/distroless/static-debian12:nonroot

# Copy binary and dependencies from builder
COPY --from=builder /app/server /app/server
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Platform metadata labels (required by Kyverno require-labels policy)
LABEL org.opencontainers.image.title="${{values.name}}" \
      org.opencontainers.image.description="${{values.description}}" \
      org.opencontainers.image.vendor="vantapay" \
      org.opencontainers.image.source="https://github.com/vantapay/${{values.name}}" \
      platform.vantapay.io/team="${{values.team}}" \
      platform.vantapay.io/slo-tier="${{values.slo_tier}}"

# Non-root user (UID 65532 is the nonroot user in distroless)
USER 65532:65532

# Port
EXPOSE ${{values.port}}

# Health check
# Note: distroless has no curl/wget, so Kubernetes probes must use HTTP
# The server handles /healthz and /readyz directly.
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/app/server", "-healthcheck"]

ENTRYPOINT ["/app/server"]
