# Pin to a specific minor + slim variant
FROM python:3.12-slim

# OCI metadata
LABEL org.opencontainers.image.title="flask-hello" \
      org.opencontainers.image.source="https://example.com/repo" \
      org.opencontainers.image.licenses="MIT"

# Build-time arg (override with --build-arg)
ARG APP_USER=appuser

# Runtime env
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000

# Create non-root user
RUN groupadd --system ${APP_USER} && \
    useradd  --system --gid ${APP_USER} --no-create-home ${APP_USER}

WORKDIR /app

# Cache-friendly: deps first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then code
COPY app.py .

# Drop privileges
USER ${APP_USER}

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/').status == 200 else 1)"

# Exec form so signals reach the app
ENTRYPOINT ["python", "app.py"]
