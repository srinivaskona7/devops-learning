# QA Engineer's Test Plan — Project 02: URL Shortener

**Executor:** anyone with Docker Desktop and `curl` installed.
**Stack under test:** FastAPI · Postgres 16 · Nginx · Docker Compose.
**Time to run full plan:** ~15 minutes.

---

## Pre-flight

```bash
# Verify the stack is up
docker compose -f infra/docker-compose.yml ps
# All 4 services should show "running (healthy)" or "running"
```

---

## Checklist

### Phase 1 — Build integrity

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 1 | API image runs as non-root | `docker inspect shortener-api --format '{{.Config.User}}'` | `1000` |
| 2 | API image has no exposed DB port | `docker port shortener-db` | empty output (no host binding) |
| 3 | nginx image version not leaked | `curl -sI http://localhost/ \| grep -i server` | no `nginx/X.Y.Z` in value |

**How to run:**
```bash
docker inspect shortener-api --format '{{.Config.User}}'
# Expected: 1000

docker port shortener-db
# Expected: (empty)

curl -sI http://localhost/ | grep -i server
# Expected: "server: nginx" — no version number
```

---

### Phase 2 — Migration idempotency

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 4 | Migration runs once — table created | `make psql` → `\dt` | `urls` table present |
| 5 | Migration runs twice — no error | `make migrate` again | exit 0, no error |

**How to run:**
```bash
make migrate
# Expected: "NOTICE: relation "urls" already exists, skipping" — exit 0

make psql
# In psql: \dt
# Expected: urls table listed
```

---

### Phase 3 — Health probes

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 6 | `/healthz` is always 200 | `curl -sf http://localhost/healthz` | `{"status":"ok"}` |
| 7 | `/ready` is 200 when DB is up | `curl -sf http://localhost/ready` | `{"status":"ready"}` |
| 8 | `/ready` is 503 when DB is stopped | Stop db, curl /ready within 5s | `503` status |

**How to run:**
```bash
curl -sf http://localhost/healthz
# Expected: {"status":"ok"}

curl -sf http://localhost/ready
# Expected: {"status":"ready"}

docker compose -f infra/docker-compose.yml stop db
sleep 3
curl -sf http://localhost/ready
# Expected: HTTP 503

docker compose -f infra/docker-compose.yml start db
# Wait for db to be healthy again (~15s)
```

---

### Phase 4 — Core API flows

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 9 | POST /api/shorten → 201 + code | `curl -X POST ... {"url":"..."}` | 201, body has `code` key |
| 10 | GET /:code → 302 redirect | `curl -I http://localhost/<code>` | `302`, `Location` header set |
| 11 | GET /:code increments `hits` | Compare hits before/after GET | hits column +1 |
| 12 | Duplicate URL returns same code | POST same URL twice | same `code` in both responses |
| 13 | GET unknown code → 404 | `curl http://localhost/zzz999` | `404` |

**How to run:**
```bash
# Test 9
curl -sf -X POST http://localhost/api/shorten \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://github.com/torvalds/linux"}' | jq .
# Expected: {"code":"aB3kQ7","short_url":"http://localhost/aB3kQ7","target":"..."}

# Test 10
curl -sI http://localhost/aB3kQ7
# Expected: HTTP/1.1 302 Found  Location: https://github.com/torvalds/linux

# Test 11 — check hits
make psql
# In psql: SELECT code, hits FROM urls WHERE code = 'aB3kQ7';
# Hit the URL again: curl -I http://localhost/aB3kQ7
# Back in psql: SELECT hits FROM urls WHERE code = 'aB3kQ7';
# Expected: hits incremented by 1

# Test 12
curl -sf -X POST http://localhost/api/shorten \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://github.com/torvalds/linux"}' | jq .code
# Expected: same code as before

# Test 13
curl -o /dev/null -w "%{http_code}" http://localhost/zzz999
# Expected: 404
```

---

### Phase 5 — Chaos / recovery

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 14 | DB restart — API recovers | Stop db, wait 30s, start db | `/ready` returns 200 within 60s |

**How to run:**
```bash
docker compose -f infra/docker-compose.yml stop db
# Wait 30s, then:
docker compose -f infra/docker-compose.yml start db
# Poll until healthy:
for i in $(seq 1 12); do
  STATUS=$(curl -o /dev/null -sw "%{http_code}" http://localhost/ready)
  echo "$i: /ready → $STATUS"
  [ "$STATUS" = "200" ] && break
  sleep 5
done
# Expected: 200 within ~60s
```

---

### Phase 6 — Performance and scale

| # | Test | Command | Pass criteria |
|---|------|---------|---------------|
| 15 | 100 VUs 2min — p95 < 150ms | `make perf` | p95 < 150ms, error rate 0% |

**How to run:**
```bash
make perf
# Expected output (k6):
#   http_req_duration p(95)=XXms  (must be < 150ms)
#   http_req_failed   0.00%
#   checks            100.00%

# Bonus: scale to 3 replicas and re-run
make scale
make perf
# Expected: similar p95, load distributed across 3 api containers
```

---

## Known failure modes and mitigations

| Failure | Symptom | Fix |
|---------|---------|-----|
| DB not started before API | `connection refused` on startup | `depends_on: condition: service_healthy` handles this |
| Missing `.env` file | Compose fails to parse `${POSTGRES_PASSWORD}` | `cp infra/.env.example infra/.env` |
| Port 80 already in use | `bind: address already in use` | `lsof -i :80` to find the blocker |
| k6 not installed | `make perf` exits 1 | `brew install k6` (macOS) or see k6.io |
| pgdata owned by root | Permission denied in postgres container | `make nuke` then `make up` (fresh volume) |
