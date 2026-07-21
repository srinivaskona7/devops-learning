"""
URL Shortener API — FastAPI + Postgres 16
Endpoints:
  GET  /healthz          → liveness probe
  GET  /ready            → readiness probe (checks DB)
  POST /api/shorten      → create short code
  GET  /api/links        → list recent links
  GET  /:code            → redirect to target URL
"""

import os
import random
import string
from contextlib import asynccontextmanager

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel, HttpUrl

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

DATABASE_URL: str = os.environ["DATABASE_URL"]


def get_conn() -> psycopg2.extensions.connection:
    """Open a new connection from the DSN in DATABASE_URL."""
    return psycopg2.connect(DATABASE_URL)


def db_ping() -> bool:
    """Return True if Postgres answers SELECT 1."""
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return True
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Short-code generation
# ---------------------------------------------------------------------------

ALPHABET = string.ascii_letters + string.digits  # base-62


def generate_code(length: int = 6) -> str:
    return "".join(random.choices(ALPHABET, k=length))


# ---------------------------------------------------------------------------
# Lifespan — runs migrations on startup
# ---------------------------------------------------------------------------

MIGRATION_DIR = os.path.join(os.path.dirname(__file__), "migrations")


def run_migrations() -> None:
    """Execute all *.sql files in migrations/ in filename order."""
    conn = get_conn()
    conn.autocommit = True
    cur = conn.cursor()
    migration_files = sorted(
        f for f in os.listdir(MIGRATION_DIR) if f.endswith(".sql")
    )
    for fname in migration_files:
        path = os.path.join(MIGRATION_DIR, fname)
        with open(path) as fh:
            sql = fh.read()
        cur.execute(sql)
        print(f"[migration] applied {fname}")
    cur.close()
    conn.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    run_migrations()
    yield


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(title="URL Shortener", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health probes
# ---------------------------------------------------------------------------


@app.get("/healthz", tags=["ops"])
def healthz():
    """Liveness probe — always 200 if the process is alive."""
    return {"status": "ok"}


@app.get("/ready", tags=["ops"])
def ready():
    """Readiness probe — 200 only when DB is reachable."""
    if not db_ping():
        raise HTTPException(status_code=503, detail="database unreachable")
    return {"status": "ready"}


# ---------------------------------------------------------------------------
# URL shortener endpoints
# ---------------------------------------------------------------------------


class ShortenRequest(BaseModel):
    url: HttpUrl


class ShortenResponse(BaseModel):
    code: str
    short_url: str
    target: str


@app.post("/api/shorten", response_model=ShortenResponse, status_code=201, tags=["shortener"])
def shorten(body: ShortenRequest, request: Request):
    """
    Create a short code for the given URL.
    Returns the code and a fully-qualified short URL.
    """
    target = str(body.url)
    conn = get_conn()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # Check for existing mapping to keep the table lean
        cur.execute("SELECT code FROM urls WHERE target = %s LIMIT 1", (target,))
        row = cur.fetchone()
        if row:
            code = row["code"]
        else:
            # Collision-safe insertion with retry
            for _ in range(10):
                code = generate_code()
                try:
                    cur.execute(
                        "INSERT INTO urls (code, target) VALUES (%s, %s)",
                        (code, target),
                    )
                    conn.commit()
                    break
                except psycopg2.errors.UniqueViolation:
                    conn.rollback()
            else:
                raise HTTPException(status_code=500, detail="could not generate unique code")
        cur.close()
    finally:
        conn.close()

    base = str(request.base_url).rstrip("/")
    return ShortenResponse(code=code, short_url=f"{base}/{code}", target=target)


@app.get("/api/links", tags=["shortener"])
def list_links(limit: int = 20):
    """Return the most recently created short links."""
    conn = get_conn()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute(
            "SELECT code, target, hits, created_at FROM urls ORDER BY created_at DESC LIMIT %s",
            (min(limit, 100),),
        )
        rows = cur.fetchall()
        cur.close()
    finally:
        conn.close()
    return {"links": [dict(r) for r in rows]}


@app.get("/{code}", tags=["shortener"])
def redirect(code: str):
    """
    Resolve a short code → 302 redirect.
    Increments the hit counter atomically.
    """
    conn = get_conn()
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(
            "UPDATE urls SET hits = hits + 1 WHERE code = %s RETURNING target",
            (code,),
        )
        row = cur.fetchone()
        conn.commit()
        cur.close()
    finally:
        conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail=f"code '{code}' not found")

    return RedirectResponse(url=row["target"], status_code=302)
