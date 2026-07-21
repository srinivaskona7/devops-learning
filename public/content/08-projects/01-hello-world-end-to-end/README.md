# Project 01 · Hello <em>World</em>, Shipped

<span class="level beginner">beginner</span>
<span class="tag">stack: docker · nginx · alpine</span>

<p class="tagline">Your first production-shaped deploy — build, run, probe, and ship a static site to a registry in under an hour.</p>

<div class="metrics" markdown>
<span class="m"><b>Time</b> 60 min</span>
<span class="m"><b>Cost</b> $0 local / ~$0.10 registry storage</span>
<span class="m"><b>Image size target</b> &lt; 10 MB</span>
<span class="m"><b>p95 target</b> &lt; 50 ms</span>
</div>

---

## Roadmap

<div class="roadmap" markdown>
<div class="stop" data-step="1" markdown>
#### Bootstrap
`make build && make run` — see the welcome page on localhost:8080 in 60 seconds.
</div>
<div class="stop" data-step="2" markdown>
#### Understand the wiring
Trace the request path: browser → Docker port publish → Nginx worker → static file. Read the Dockerfile top-to-bottom.
</div>
<div class="stop" data-step="3" markdown>
#### Probe it
`make test` — automated curl checks confirm 200 OK, security headers, and non-root UID.
</div>
<div class="stop" data-step="4" markdown>
#### Benchmark it
`make perf` — k6 fires 50 VUs for 2 minutes. p95 stays under 50 ms on any modern laptop.
</div>
<div class="stop" data-step="5" markdown>
#### Ship it
`make push REGISTRY=ghcr.io/yourname` — tag and push to your registry. Same bytes, anywhere.
</div>
</div>

---

## Reason — why Docker for a static site?

<div class="concept" markdown>

> Your team ships a marketing redesign. It works on your laptop. On staging it shows a blank page — different nginx version, missing MIME type, misconfigured gzip. You've seen this. Docker eliminates it.

Static sites are the perfect entry point into containers because they have **zero runtime dependencies** — nothing to compile at request time, no database, no secret rotation. That simplicity lets you focus entirely on the container fundamentals that apply to every more complex project:

| Principle | What it means in practice |
|-----------|--------------------------|
| **Reproducible builds** | The image is the artifact. Dev, CI, and prod run identical bytes. |
| **Immutable deploys** | You never patch a running container — you replace it with a new image. |
| **Registry as source of truth** | Every image is tagged, pullable, and auditable. |
| **Security defaults from day zero** | Non-root user and read-only filesystem are habits, not afterthoughts. |

This is exactly how **Vercel**, **Cloudflare Pages**, and **GitHub Pages** work under the hood. You're building their pattern at 1:1 scale.

</div>

---

## Thinking — Dockerfile anatomy

<div class="concept" markdown>

A Dockerfile is a reproducible recipe. Every instruction creates an immutable layer. Layers that haven't changed are cached — that's why instruction order matters.

```dockerfile
FROM node:alpine AS builder        # stage 1: build tools available
WORKDIR /build
COPY app/ .                        # only copy what you need

FROM nginx:alpine                  # stage 2: clean runtime image
COPY --from=builder /build \
     /usr/share/nginx/html         # only the output arrives here
```

**Instruction order rules:**

1. Put `FROM` / base-image pulls first — they're the slowest and change least often.
2. `COPY` dependencies before `COPY` source — so a source-only change doesn't bust dependency caches.
3. `RUN` steps that change rarely go before steps that change often.
4. Always end with `CMD` — Docker's entrypoint is the last instruction.

</div>

---

## Thinking — multi-stage build

<div class="stage" markdown>

### Stage 1 · Builder (`node:alpine`)

| Item | Explanation |
|------|-------------|
| `node:alpine` base | Alpine Linux is ~5 MB vs ~150 MB for Debian slim. Node is here in case you add a build step (sass, esbuild, webpack). |
| `COPY app/ .` | Copy only the app source — never infra files or test files. |
| Sanity checks | `RUN test -s index.html` — fail fast at build time, not at runtime. |
| Result | A `/build` directory with verified assets — ready to be copied. |

### Stage 2 · Runtime (`nginx:alpine`)

| Item | Explanation |
|------|-------------|
| Fresh `FROM nginx:alpine` | Clean slate — no node, no npm, no build caches in the final image. |
| `COPY --from=builder` | Pull only the compiled output. Build tools never reach the shipped image. |
| `USER nginx` (UID 101) | If nginx is compromised, the attacker holds UID 101 — no OS write access. |
| `HEALTHCHECK` | Docker engine monitors liveness. Orchestrators gate traffic on it. |
| `STOPSIGNAL SIGQUIT` | Nginx drains open connections gracefully before exiting. |

**Final image:**
```text
nginx:alpine base layer  ~8.5 MB
html + css layer           ~12 KB
──────────────────────────────────
Total                    ~8.5 MB   ✔ well under 10 MB
```

</div>

---

## Thinking — security hardening

<div class="concept" markdown>

Three layers of defence, each costing nothing extra:

**1. Non-root user**
```dockerfile
# nginx:alpine already creates uid=101 (nginx) — we just use it
USER nginx
```
`docker exec hello id` shows `uid=101(nginx)`. A compromised worker process cannot write to `/usr/bin`, install packages, or read `/etc/shadow`.

**2. Read-only root filesystem**
```bash
docker run --read-only \
  --tmpfs /var/cache/nginx:rw,size=16m \
  --tmpfs /var/run:rw,size=4m \
  myimage
```
The Makefile passes these flags. Every write outside the two tmpfs mounts returns `Read-only file system`. An attacker with a file-write primitive has nowhere to land.

**3. Nginx security headers**
```nginx
server_tokens off;                           # hides "nginx/1.27.x"
add_header X-Frame-Options         "DENY";   # no iframe embedding
add_header X-Content-Type-Options  "nosniff"; # no MIME sniffing
add_header Content-Security-Policy "default-src 'self'; ...";
```
These three lines close entire OWASP Top-10 categories before the app even runs.

</div>

---

## Thinking — healthcheck probe

<div class="concept" markdown>

Docker's `HEALTHCHECK` instruction tells the daemon how to verify the container is serving — not just running as a process.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -q -O- --spider http://127.0.0.1/ || exit 1
```

| Flag | Value | Meaning |
|------|-------|---------|
| `--interval` | 30s | Check every 30 seconds |
| `--timeout` | 3s | Fail the check if no response in 3 s |
| `--start-period` | 2s | Grace window on first start |
| `--retries` | 3 | Mark `unhealthy` after 3 consecutive failures |

`docker ps` shows `(healthy)` once the probe passes. Kubernetes uses this to gate traffic during rollouts — it will not send requests until the healthcheck succeeds.

</div>

---

## Thinking — registry push

<div class="concept" markdown>

A container registry is a versioned artifact store. The workflow maps to git push/pull:

```bash
docker build → docker tag → docker push → docker pull (anywhere)
```

**Tagging strategy:**

| Tag | Use |
|-----|-----|
| `latest` | Development shorthand — never pin production deploys to `latest` |
| `v1.0.0` | Semantic version — pinnable, auditable |
| `sha-abc1234` | Git SHA — ties the image to an exact commit. Use this in CI/CD. |

**Free registries:**

| Registry | Image prefix | Free tier |
|----------|-------------|-----------|
| Docker Hub | `docker.io/username/repo` | 1 private repo |
| GitHub GHCR | `ghcr.io/username/repo` | Free for public repos |
| AWS ECR Public | `public.ecr.aws/alias/repo` | Free worldwide pulls |

```bash
# tag + push to GHCR
docker tag hello-world:0.1.0 ghcr.io/yourname/hello-world:0.1.0
docker push ghcr.io/yourname/hello-world:0.1.0

# pull on any machine
docker pull ghcr.io/yourname/hello-world:0.1.0
docker run -p 8080:80 ghcr.io/yourname/hello-world:0.1.0
```

The `make push` target uses `REGISTRY` and `TAG` env vars so you can swap registries without touching the Makefile.

</div>

---

## Execution — run it

```bash
# 1. Build the image (runs multi-stage Dockerfile)
make build

# 2. Start with security flags: non-root, read-only rootfs, cap-drop
make run

# 3. Open http://localhost:8080 in your browser

# 4. Automated E2E checks (200 OK, security headers, UID, readonly test)
make test

# 5. Load test (k6 required: brew install k6 / apt install k6)
make perf

# 6. Push to a registry
REGISTRY=ghcr.io/yourname make push

# 7. Stop and clean up
make stop
make clean
```

One-liner to run without make:

```bash
docker run --rm -d --name hello -p 8080:80 \
  --read-only \
  --tmpfs /var/cache/nginx:rw,size=16m \
  --tmpfs /var/run:rw,size=4m \
  --cap-drop=ALL \
  --cap-add=CHOWN --cap-add=SETUID --cap-add=SETGID \
  --cap-add=NET_BIND_SERVICE --cap-add=DAC_OVERRIDE \
  --security-opt=no-new-privileges \
  hello-world:0.1.0
```

---

## Simulation — what you'll see

<pre class="sim"><code><span class="prompt">$</span> make build
<span class="comment"># [+] Building 4.2s (8/8) FINISHED</span>
<span class="comment"># => [builder 1/3] FROM docker.io/library/node:alpine</span>
<span class="comment"># => [builder 2/3] WORKDIR /build</span>
<span class="comment"># => [builder 3/3] COPY app/ .</span>
<span class="comment"># => [runtime 1/3] FROM docker.io/library/nginx:1.27-alpine-slim</span>
<span class="comment"># => [runtime 2/3] COPY infra/nginx.conf /etc/nginx/nginx.conf</span>
<span class="comment"># => [runtime 3/3] COPY --from=builder /build /usr/share/nginx/html</span>
<span class="comment"># ✔ Image size: 8.7 MB  (target &lt; 10 MB)</span>

<span class="prompt">$</span> make run
<span class="comment"># Container hello started on :8080</span>
<span class="comment"># --read-only --tmpfs /var/cache/nginx --tmpfs /var/run</span>
<span class="comment"># --cap-drop=ALL --security-opt=no-new-privileges</span>
<span class="comment"># ✔ http://localhost:8080/ → 200 OK</span>

<span class="prompt">$</span> make test
<span class="comment"># [1/5] HTTP 200 OK ........................ PASS</span>
<span class="comment"># [2/5] X-Frame-Options: DENY .............. PASS</span>
<span class="comment"># [3/5] X-Content-Type-Options: nosniff .... PASS</span>
<span class="comment"># [4/5] Non-root UID (101) ................. PASS</span>
<span class="comment"># [5/5] Read-only rootfs (write refused) ... PASS</span>

<span class="prompt">$</span> make perf
<span class="comment"># k6 — 50 VUs × 2 minutes</span>
<span class="comment"># ✔ http_req_duration p(50)=4ms  p(95)=18ms  (target &lt; 50ms)</span>
<span class="comment"># ✔ http_req_failed   0.00%</span>
<span class="comment"># ✔ requests completed: 387 342</span>
</code></pre>

---

## Output — before and after security hardening

<div class="flow" markdown>

<div class="state before" markdown>
##### Default `nginx:latest`
<span class="diff-del">root user (UID 0)</span>
<span class="diff-del">writable rootfs</span>
<span class="diff-del">server_tokens on (leaks version)</span>
Image: ~140 MB · Debian base
</div>

<div class="arrow">→</div>

<div class="state during" markdown>
##### + multi-stage + alpine
<span class="diff-mod">nginx user (UID 101)</span>
<span class="diff-del">writable rootfs</span>
<span class="diff-mod">server_tokens off</span>
Image: 8.7 MB · alpine slim
</div>

<div class="arrow">→</div>

<div class="state after" markdown>
##### + read-only + headers
<span class="diff-add">UID 101 (nginx) · non-root</span>
<span class="diff-add">read-only rootfs + tmpfs</span>
<span class="diff-add">X-Frame, CSP, nosniff headers</span>
Image: 8.7 MB · hardened
</div>

</div>

---

## Real-world use case

<div class="usecase-card" markdown>

**At Vercel**, every static site deploy is a container image pushed to an internal registry and routed by their edge network. Your `index.html` becomes an immutable artifact tagged with the Git SHA — if the new deploy breaks, they roll back by routing to the previous image tag in under a second. The pattern you're practising here — build, tag, push, pull-by-digest — is the exact workflow their platform automates for millions of sites.

</div>

<div class="usecase-card" markdown>

**At Cloudflare Pages**, your HTML/CSS is bundled into a Worker Sites KV namespace. Under the hood it's the same contract: immutable artifact, globally distributed, rollback by version. The security headers you configure in `nginx.conf` map directly to the `_headers` file Cloudflare Pages reads at deploy time.

</div>

---

## QA engineer's test plan

See [`tests/qa-plan.md`](./tests/qa-plan.md). Summary:

| # | Test | Tool | Pass criteria |
|---|------|------|---------------|
| 1 | HTTP 200 on `/` | curl | `HTTP/1.1 200 OK` |
| 2 | `X-Frame-Options: DENY` | curl -I | header present |
| 3 | `X-Content-Type-Options: nosniff` | curl -I | header present |
| 4 | `Content-Security-Policy` present | curl -I | header present |
| 5 | Image size < 10 MB | `docker image inspect` | `.Size` < 10 485 760 bytes |
| 6 | Process runs as non-root | `docker exec ... id` | UID = 101 |
| 7 | Read-only rootfs enforced | `docker exec ... touch /test` | permission denied |
| 8 | Healthcheck passes | `docker inspect` | `State.Health.Status = healthy` |
| 9 | p95 < 50 ms at 50 VUs | k6 | `p(95) < 50ms`, errors = 0 |
| 10 | No HIGH/CRITICAL CVEs | `docker scout cves` | 0 HIGH/CRITICAL |

---

## Performance baseline

k6 script in [`tests/k6/smoke.js`](./tests/k6/smoke.js). Run with `make perf`. Expected baseline on a 2020+ machine:

| Metric | Target | Typical result |
|--------|--------|---------------|
| RPS | ≥ 3 000 | ~3 500 (nginx static content is exceptionally fast) |
| p50 | < 10 ms | ~4 ms (kernel page-cache hits after warm-up) |
| p95 | < 50 ms | ~18 ms |
| p99 | < 100 ms | ~35 ms |
| Error rate | 0.00% | 0.00% |

---

## Files in this project

| File | Purpose |
|------|---------|
| [`app/index.html`](./app/index.html) | Welcome page — Bricolage Grotesque + Fraunces, soft aurora gradient |
| [`app/styles.css`](./app/styles.css) | Clean CSS — responsive, dark mode, animated aurora background |
| [`infra/Dockerfile`](./infra/Dockerfile) | Multi-stage: `node:alpine` builder → `nginx:1.27-alpine-slim` runtime |
| [`infra/nginx.conf`](./infra/nginx.conf) | Hardened nginx: gzip, security headers, tmpfs-safe temp paths |
| [`Makefile`](./Makefile) | `build / run / test / perf / push / stop / clean` |
| [`tests/qa-plan.md`](./tests/qa-plan.md) | 10-item QA checklist — runnable by anyone |
| [`tests/k6/smoke.js`](./tests/k6/smoke.js) | 50 VUs × 2 min load test, p95 < 50 ms target |
| [`tests/e2e/check.sh`](./tests/e2e/check.sh) | Bash: curl 200, header checks, non-root UID, read-only rootfs |
| [`architecture.md`](./architecture.md) | Request-path deep-dive with mermaid diagram |

---

## Further reading

- Architecture deep-dive: [`architecture.md`](./architecture.md)
- QA plan: [`tests/qa-plan.md`](./tests/qa-plan.md)
- Next project: [02 — Three-tier app with Docker Compose](../02-three-tier-app/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Docker security best practices](https://docs.docker.com/engine/security/)
- [Mozilla CSP reference](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
