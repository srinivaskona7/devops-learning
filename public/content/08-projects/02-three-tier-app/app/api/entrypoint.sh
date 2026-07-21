#!/bin/sh
# entrypoint.sh — run migrations then hand off to uvicorn
set -e

echo "[entrypoint] running migrations..."
psql "${DATABASE_URL}" -f /app/migrations/001_init.sql

echo "[entrypoint] starting api..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
