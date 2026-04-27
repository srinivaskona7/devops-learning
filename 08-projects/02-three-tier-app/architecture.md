# Architecture — Three-Tier URL Shortener

Deep-dive on the Docker Compose topology: request flow, data path, and health probe path for `02-three-tier-app`.

---

## 1. Full topology

```mermaid
flowchart LR
  Client["fa:fa-user Browser / curl"]

  subgraph host ["Host machine — localhost"]
    Port80["port :80\n(only published port)"]
  end

  subgraph net ["Docker bridge: shortener-net"]
    Nginx["nginx\n:80 (internal)\nreverse proxy"]
    API["api\nFastAPI :8000\nnon-root UID 1000\n2 replicas (scaled)"]
    DB[("db\npostgres:16-alpine\n:5432\nhealthcheck: pg_isready")]
    Adminer["adminer\n:8080 (internal only)"]
  end

  Vol[("pgdata\nnamed Docker volume")]

  Client -->|HTTP :80| Port80
  Port80 --> Nginx
  Nginx -->|"proxy_pass http://api:8000"| API
  API -->|"psycopg2 DSN"| DB
  DB --- Vol
  Adminer --> DB
```

---

## 2. Request flow — POST /api/shorten

```mermaid
sequenceDiagram
  participant C as curl / Browser
  participant N as nginx :80
  participant A as api :8000
  participant D as postgres :5432

  C->>N: POST /api/shorten {"url":"https://..."}
  N->>A: proxy_pass POST /api/shorten
  A->>A: generate 6-char base62 code
  A->>D: INSERT INTO urls (code, target) VALUES ($1, $2)
  D-->>A: INSERT 0 1
  A-->>N: 201 {"code":"aB3kQ7","short_url":"http://localhost/aB3kQ7"}
  N-->>C: 201 (X-Content-Type-Options, X-Frame-Options headers added)
```

---

## 3. Request flow — GET /:code (redirect)

```mermaid
sequenceDiagram
  participant C as Browser
  participant N as nginx :80
  participant A as api :8000
  participant D as postgres :5432

  C->>N: GET /aB3kQ7
  N->>A: proxy_pass GET /aB3kQ7
  A->>D: SELECT target FROM urls WHERE code = $1
  D-->>A: https://github.com/torvalds/linux
  A->>D: UPDATE urls SET hits = hits + 1 WHERE code = $1
  D-->>A: UPDATE 1
  A-->>N: 302 Location: https://github.com/torvalds/linux
  N-->>C: 302 (browser follows Location header)
```

---

## 4. Health probe path

```mermaid
sequenceDiagram
  participant DC as Docker Compose daemon
  participant DB as postgres :5432
  participant A as api :8000
  participant N as nginx (upstream check)

  Note over DC,DB: every 5s
  DC->>DB: pg_isready -U shortener -d shortener
  DB-->>DC: accepting connections → Healthy

  Note over DC,A: every 10s (after DB healthy)
  DC->>A: GET /healthz
  A-->>DC: 200 {"status":"ok"} → Healthy

  Note over DC,A: every 10s
  DC->>A: GET /ready  (checks DB connection)
  A->>DB: SELECT 1
  DB-->>A: 1
  A-->>DC: 200 {"status":"ready"} → Healthy

  Note over N,A: nginx passive health check
  N->>A: proxy request
  A-->>N: 5xx or timeout → upstream marked down (1 fail_timeout=10s)
```

---

## 5. Data path — migrations

```mermaid
sequenceDiagram
  participant E as entrypoint.sh (api container start)
  participant P as psql CLI
  participant D as postgres :5432

  E->>P: psql $DATABASE_URL -f /migrations/001_init.sql
  P->>D: CREATE TABLE IF NOT EXISTS urls (...)
  D-->>P: CREATE TABLE (or NOTICE: already exists — idempotent)
  P-->>E: exit 0
  E->>E: exec uvicorn main:app --host 0.0.0.0 --port 8000
```

---

## 6. Secret injection path

```mermaid
flowchart LR
  EnvFile[".env file\n(git-ignored)"] -->|env_file directive| Compose["docker-compose.yml"]
  Compose -->|environment variable injection| API["api container\nPOSTGRES_PASSWORD"]
  Compose -->|environment variable injection| DB["db container\nPOSTGRES_PASSWORD"]
  API -->|builds DSN at runtime| DSN["postgresql://shortener:$PW@db:5432/shortener"]
```

---

## 7. Network security model

| Source | Destination | Port | Allowed? |
|--------|-------------|------|----------|
| Host / internet | nginx | 80 | Yes — only published port |
| nginx | api | 8000 | Yes — same bridge |
| api | db | 5432 | Yes — same bridge |
| adminer | db | 5432 | Yes — same bridge |
| Host | api | 8000 | No — not published |
| Host | db | 5432 | No — not published |
| Host | adminer | 8080 | No — not published |
| Internet | db | any | No |

---

## 8. Volume lifecycle

| Command | pgdata volume |
|---------|---------------|
| `make up` | Created if absent; mounted at `/var/lib/postgresql/data` |
| `make down` | Volume persists — data safe |
| `make restart` | Volume persists |
| `make nuke` (`docker compose down -v`) | Volume deleted — data gone |

Named volumes survive container removal because Docker manages them independently of container lifecycle. This mirrors production behaviour where a database PersistentVolumeClaim outlives a pod restart.

---

## 9. Resource footprint

| Service | Image | Approx RAM |
|---------|-------|-----------|
| db | postgres:16-alpine | ~50 MB idle |
| api | python:3.12-slim (custom) | ~80 MB |
| nginx | nginx:1.27-alpine | ~8 MB |
| adminer | adminer:4 | ~30 MB |

Total stack: ~170 MB RAM on a laptop. Suitable for any 8 GB machine.
