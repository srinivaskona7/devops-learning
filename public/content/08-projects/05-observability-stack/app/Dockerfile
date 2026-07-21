# ── Stage 1: build dependencies ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM python:3.12-slim

LABEL org.opencontainers.image.title="obs-demo" \
      org.opencontainers.image.description="OTel-instrumented FastAPI service" \
      org.opencontainers.image.version="1.0.0"

# Non-root user
RUN useradd -m -u 1001 appuser
WORKDIR /app

COPY --from=builder /install /usr/local
COPY main.py .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
