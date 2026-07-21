# ── Stage 1: build ───────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /src

# Cache module downloads separately from source.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# CGO_ENABLED=0 produces a fully static binary — required for distroless.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /app/server .

# ── Stage 2: minimal runtime ──────────────────────────────────────────────────
# gcr.io/distroless/static has no shell, no package manager — smallest attack surface.
FROM gcr.io/distroless/static:nonroot

# nonroot UID 65532 is baked into the distroless image.
USER nonroot:nonroot

COPY --from=builder --chown=nonroot:nonroot /app/server /server

EXPOSE 8080

# Prometheus scrape port is the same as HTTP.
# Health probe: /healthz
ENTRYPOINT ["/server"]
