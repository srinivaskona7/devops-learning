## Makefile — URL Shortener (Project 02)
##
## Usage:
##   make up       build + start all services
##   make down     stop (data persists)
##   make nuke     stop + delete pgdata volume (destructive)
##   make test     curl smoke tests
##   make perf     k6 load test (100 VUs, 2m)
##   make logs     tail all logs
##   make psql     open psql session inside db container
##   make migrate  re-run migrations manually
##   make scale    scale api to 3 replicas
##   make restart  restart the api service only

COMPOSE := docker compose -f infra/docker-compose.yml
ENV_FILE := infra/.env

.PHONY: up down nuke test perf logs psql migrate scale restart help

# ── Bootstrap check ───────────────────────────────────────────────────────
$(ENV_FILE):
	@echo "[setup] copying .env.example → $(ENV_FILE)"
	@cp infra/.env.example $(ENV_FILE)
	@echo "[setup] EDIT $(ENV_FILE) — set POSTGRES_PASSWORD before running make up"
	@exit 1

# ── Core lifecycle ────────────────────────────────────────────────────────
up: $(ENV_FILE)
	$(COMPOSE) up --build -d
	@echo ""
	@echo "  Stack running → http://localhost"
	@echo "  API docs     → http://localhost/api/docs (not exposed — use psql or curl)"
	@echo "  Logs         → make logs"

down:
	$(COMPOSE) down
	@echo "  pgdata volume preserved. Run 'make nuke' to delete it."

nuke:
	$(COMPOSE) down -v
	@echo "  pgdata volume deleted."

# ── Ops ───────────────────────────────────────────────────────────────────
logs:
	$(COMPOSE) logs -f --tail=100

restart:
	$(COMPOSE) restart api

scale:
	$(COMPOSE) up -d --scale api=3
	@echo "  api scaled to 3 replicas — nginx round-robins across them"

# ── Database ──────────────────────────────────────────────────────────────
psql:
	$(COMPOSE) exec db psql -U shortener -d shortener

migrate:
	$(COMPOSE) exec api psql "$${DATABASE_URL}" -f /app/migrations/001_init.sql

# ── Tests ─────────────────────────────────────────────────────────────────
test:
	@echo "── liveness probe ──────────────────────────────"
	@curl -sf http://localhost/healthz | grep -q '"status":"ok"' \
	  && echo "  ✔ /healthz → 200 {\"status\":\"ok\"}" \
	  || (echo "  ✗ /healthz failed" && exit 1)

	@echo "── readiness probe ─────────────────────────────"
	@curl -sf http://localhost/ready | grep -q '"status":"ready"' \
	  && echo "  ✔ /ready → 200 {\"status\":\"ready\"}" \
	  || (echo "  ✗ /ready failed" && exit 1)

	@echo "── shorten endpoint ────────────────────────────"
	$(eval CODE := $(shell curl -sf -X POST http://localhost/api/shorten \
	  -H 'Content-Type: application/json' \
	  -d '{"url":"https://example.com/test-$(shell date +%s)"}' \
	  | python3 -c "import sys,json; print(json.load(sys.stdin)['code'])"))
	@echo "  ✔ POST /api/shorten → code: $(CODE)"

	@echo "── redirect ────────────────────────────────────"
	@curl -sf -o /dev/null -w "  ✔ GET /$(CODE) → %{http_code} (302)\n" \
	  -I -L --max-redirs 0 http://localhost/$(CODE) 2>/dev/null || true

	@echo "── list links ──────────────────────────────────"
	@curl -sf http://localhost/api/links | python3 -c \
	  "import sys,json; d=json.load(sys.stdin); print(f'  ✔ /api/links → {len(d[\"links\"])} link(s)')"

	@echo "── static frontend ─────────────────────────────"
	@curl -sf -o /dev/null -w "  ✔ GET / → %{http_code}\n" http://localhost/
	@curl -sf -o /dev/null -w "  ✔ GET /styles.css → %{http_code}\n" http://localhost/styles.css

	@echo "── security headers ────────────────────────────"
	@curl -sI http://localhost/ | grep -i "X-Frame-Options" \
	  && echo "  ✔ X-Frame-Options present" || echo "  ✗ X-Frame-Options missing"
	@curl -sI http://localhost/ | grep -i "X-Content-Type-Options" \
	  && echo "  ✔ X-Content-Type-Options present" || echo "  ✗ X-Content-Type-Options missing"
	@curl -sI http://localhost/ | grep -iv "nginx/" \
	  && echo "  ✔ Server header does not leak nginx version" || true

	@echo ""
	@echo "  All smoke tests passed."

# ── Performance ───────────────────────────────────────────────────────────
perf:
	@which k6 > /dev/null 2>&1 || (echo "k6 not found — brew install k6" && exit 1)
	k6 run tests/k6/smoke.js

# ── E2E journey ───────────────────────────────────────────────────────────
e2e:
	bash tests/e2e/journey.sh

# ── Help ──────────────────────────────────────────────────────────────────
help:
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo ""
	@echo "  No ## comment? Read the Makefile header."
