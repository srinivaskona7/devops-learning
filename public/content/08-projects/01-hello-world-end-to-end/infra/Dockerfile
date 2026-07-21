# syntax=docker/dockerfile:1.7
# ─────────────────────────────────────────────────────────────────────────────
# Project 01 · Hello World — DevOps Learning Lab
#
# Multi-stage build:
#   Stage 1 (builder) — node:alpine  : copy + validate static assets
#   Stage 2 (runtime) — nginx:alpine : hardened production image
#
# Security controls applied:
#   - Non-root user (uid=101, nginx built-in)
#   - HEALTHCHECK with wget (no curl needed in alpine)
#   - STOPSIGNAL SIGQUIT  → graceful drain on docker stop
#   - OCI labels for auditability
#
# Runtime flags (handled by Makefile / docker run):
#   --read-only
#   --tmpfs /var/cache/nginx:rw,size=16m
#   --tmpfs /var/run:rw,size=4m
#   --cap-drop=ALL
#   --cap-add=CHOWN,SETUID,SETGID,NET_BIND_SERVICE,DAC_OVERRIDE
#   --security-opt=no-new-privileges
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: builder ────────────────────────────────────────────────────────
# node:alpine is here as a placeholder for a real build step (sass, esbuild,
# Hugo, etc.). For this project the "build" is just a copy + sanity check.
# Keeping the stage means you can add npm install / npx vite build later
# without changing the runtime stage at all.
FROM node:alpine AS builder

WORKDIR /build

# Copy only the app source directory. infra/, tests/, and Makefile never
# belong in a container image — even in an intermediate stage.
COPY app/ ./

# Fail fast at build time rather than silently serving empty files.
# Also strips Windows CRLF line endings that can corrupt HTML/CSS rendering.
RUN set -eux; \
    test -s index.html || (echo "ERROR: index.html is missing or empty" && exit 1); \
    test -s styles.css || (echo "ERROR: styles.css is missing or empty" && exit 1); \
    sed -i 's/\r$//' index.html styles.css; \
    echo "build ok — $(wc -c < index.html) bytes html · $(wc -c < styles.css) bytes css"


# ── Stage 2: runtime ────────────────────────────────────────────────────────
# nginx:1.27-alpine-slim is ~8.5 MB. It ships the nginx binary plus the
# minimum alpine packages nginx needs. No shell by default (good for attack
# surface), but `sh` is available via the alpine base if needed for debugging.
#
# The `nginx` user (UID 101 / GID 101) is created by the base image.
# We do NOT recreate it — that keeps this stage's layer count minimal.
FROM nginx:1.27-alpine-slim AS runtime

# OCI standard labels — used by container registries, scanners, and dashboards.
LABEL org.opencontainers.image.title="hello-world"
LABEL org.opencontainers.image.description="Project 01 · DevOps Learning Lab · multi-stage nginx welcome page"
LABEL org.opencontainers.image.source="https://github.com/devops-learning-lab/08-projects/01-hello-world-end-to-end"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="0.1.0"

# Overlay the default nginx config with our hardened version.
# This must come BEFORE copying assets so that config errors fail early.
COPY infra/nginx.conf /etc/nginx/nginx.conf

# Copy validated assets from the builder stage.
# --chown ensures the nginx worker (uid=101) can read the files.
COPY --from=builder --chown=nginx:nginx /build/index.html /usr/share/nginx/html/index.html
COPY --from=builder --chown=nginx:nginx /build/styles.css  /usr/share/nginx/html/styles.css

# Remove the default nginx welcome page — we serve our own.
RUN rm -f /usr/share/nginx/html/50x.html

# Document the port nginx listens on. The host-side mapping (8080:80)
# is specified at `docker run` time, not here.
EXPOSE 80

# Healthcheck — Docker engine polls this every 30 s.
# wget ships with BusyBox in alpine; --spider does a HEAD-only request.
# Kubernetes uses this to gate rolling updates.
HEALTHCHECK --interval=30s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -q -O- --spider http://127.0.0.1/ || exit 1

# SIGQUIT triggers graceful nginx shutdown — drains in-flight connections
# before stopping. Without this, `docker stop` sends SIGTERM which closes
# connections immediately and causes client errors during restarts.
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
