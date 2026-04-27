-- Migration 001 — initial schema
-- Idempotent: safe to run on every container start.

CREATE TABLE IF NOT EXISTS urls (
    id         BIGSERIAL    PRIMARY KEY,
    code       VARCHAR(12)  NOT NULL UNIQUE,
    target     TEXT         NOT NULL,
    hits       BIGINT       NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_urls_code       ON urls (code);
CREATE INDEX IF NOT EXISTS idx_urls_created_at ON urls (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_urls_target     ON urls (target);
