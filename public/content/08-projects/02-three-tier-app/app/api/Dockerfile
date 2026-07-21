# syntax=docker/dockerfile:1

# ---- builder stage ----
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build deps only in this stage
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---- runtime stage ----
FROM python:3.12-slim AS runtime

# Install libpq runtime (psycopg2-binary needs it)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN groupadd --gid 1000 app && \
    useradd  --uid 1000 --gid app --shell /bin/sh --create-home app

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy source
COPY --chown=app:app . .

# Entrypoint: run migrations then start uvicorn
COPY --chown=app:app entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER 1000

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
