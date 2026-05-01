# Graph Report - Devops-learning  (2026-05-01)

## Corpus Check
- 26 files · ~781,808 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 130 nodes · 159 edges · 11 communities detected
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 12|Community 12]]

## God Nodes (most connected - your core abstractions)
1. `main()` - 10 edges
2. `get_conn()` - 7 edges
3. `envOr()` - 5 edges
4. `Server` - 5 edges
5. `run_migrations()` - 5 edges
6. `shorten()` - 5 edges
7. `open()` - 4 edges
8. `patch_file()` - 4 edges
9. `setup()` - 4 edges
10. `handleSummary()` - 4 edges

## Surprising Connections (you probably didn't know these)
- `open()` --calls--> `run_migrations()`  [INFERRED]
  docs/javascripts/palette.js → 08-projects/02-three-tier-app/app/api/main.py
- `healthzHandler()` --calls--> `TestHealthzHandler()`  [INFERRED]
  08-projects/09-zero-downtime-progressive-delivery/app/main.go → 08-projects/04-ci-cd-pipeline/app/main_test.go
- `readyHandler()` --calls--> `TestReadyHandler()`  [INFERRED]
  08-projects/04-ci-cd-pipeline/app/main.go → 08-projects/04-ci-cd-pipeline/app/main_test.go
- `helloHandler()` --calls--> `TestHelloHandler()`  [INFERRED]
  08-projects/04-ci-cd-pipeline/app/main.go → 08-projects/04-ci-cd-pipeline/app/main_test.go
- `main()` --calls--> `newMux()`  [EXTRACTED]
  08-projects/10-platform-engineering-end-to-end/golden-path/skeleton/app/main.go → 08-projects/04-ci-cd-pipeline/app/main.go

## Communities

### Community 0 - "Community 0"
Cohesion: 0.13
Nodes (22): db_ping(), generate_code(), get_conn(), healthz(), lifespan(), list_links(), URL Shortener API — FastAPI + Postgres 16 Endpoints:   GET  /healthz          →, Liveness probe — always 200 if the process is alive. (+14 more)

### Community 1 - "Community 1"
Cohesion: 0.2
Nodes (11): apiResponse, Config, apiHandler(), badWeight(), configFromEnv(), envOr(), getEnv(), initTracer() (+3 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (11): cpu(), fast(), flaky(), prometheus_metrics(), Project 05 · Observability Stack — Instrumented FastAPI Service ================, Prometheus scrape endpoint — consumed by ServiceMonitor., Returns immediately. Baseline latency ~1 ms., Simulates a slow DB query. p95 ~2 s. (+3 more)

### Community 3 - "Community 3"
Cohesion: 0.21
Nodes (10): HealthResponse, HelloResponse, healthzHandler(), helloHandler(), newMux(), readyHandler(), TestHealthzHandler(), TestHelloHandler() (+2 more)

### Community 4 - "Community 4"
Cohesion: 0.24
Nodes (6): handleSummary(), textSummary(), getDrillPhase(), handleSummary(), testApiRead(), testHealthCheck()

### Community 5 - "Community 5"
Cohesion: 0.36
Nodes (7): close(), go(), loadIndex(), open(), render(), score(), search()

### Community 6 - "Community 6"
Cohesion: 0.33
Nodes (4): handleSummary(), setup(), teardown(), textSummary()

### Community 8 - "Community 8"
Cohesion: 0.6
Nodes (4): main(), patch_file(), Returns (rendered, total)., render()

### Community 9 - "Community 9"
Cohesion: 0.67
Nodes (2): init(), load()

### Community 10 - "Community 10"
Cohesion: 0.67
Nodes (2): main(), process()

### Community 12 - "Community 12"
Cohesion: 1.0
Nodes (2): collapse(), main()

## Knowledge Gaps
- **20 isolated node(s):** `Returns (rendered, total).`, `HelloResponse`, `HealthResponse`, `apiResponse`, `Config` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 9`** (4 nodes): `progress.js`, `init()`, `load()`, `save()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 10`** (4 nodes): `main()`, `patch_tag()`, `process()`, `lazy-images.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 12`** (3 nodes): `collapse()`, `main()`, `fix-mermaid-duplicates.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `Community 1` to `Community 3`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `run_migrations()` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Why does `open()` connect `Community 5` to `Community 0`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **What connects `Returns (rendered, total).`, `HelloResponse`, `HealthResponse` to the rest of the system?**
  _20 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._