# QA Plan — Project 01 · Hello World on Docker

> Anyone with Docker installed can run this plan end-to-end. No knowledge of the codebase required.

---

## Prerequisites

```bash
docker --version          # ≥ 24.0
curl --version            # any modern version
k6 version                # ≥ 0.48 (or: docker pull grafana/k6)
docker scout version      # optional — Docker Desktop or plugin install
```

The container must already be running before executing most checks.
Start it with:

```bash
cd 08-projects/01-hello-world-end-to-end
make build
make run
```

---

## Checklist

### 1 · HTTP 200 on root path

**What:** The server must return `200 OK` for a `GET /`.

**Command:**
```bash
STATUS=$(curl -o /dev/null -s -w "%{http_code}" http://localhost:8080/)
echo "Status: $STATUS"
```

**Pass criteria:** `Status: 200`

**Fail action:** Check `docker logs hello` for nginx errors. Confirm the container is running with `docker ps`.

---

### 2 · X-Frame-Options: DENY

**What:** Clickjacking protection — the browser must refuse to embed this page in an `<iframe>`.

**Command:**
```bash
curl -sI http://localhost:8080/ | grep -i "x-frame-options"
```

**Pass criteria:** Output contains `x-frame-options: DENY` (case-insensitive).

**Fail action:** Check the `add_header X-Frame-Options` directive in `infra/nginx.conf`. Ensure it is inside the `server {}` block, not above it.

---

### 3 · X-Content-Type-Options: nosniff

**What:** MIME-sniffing protection — prevents browsers from guessing a file's content type.

**Command:**
```bash
curl -sI http://localhost:8080/ | grep -i "x-content-type-options"
```

**Pass criteria:** Output contains `x-content-type-options: nosniff`.

---

### 4 · Content-Security-Policy header present

**What:** CSP restricts which scripts, styles, and origins the browser will load. Absence means XSS is trivially easy.

**Command:**
```bash
curl -sI http://localhost:8080/ | grep -i "content-security-policy"
```

**Pass criteria:** Line starts with `content-security-policy:`.

**Fail action:** Verify the `add_header Content-Security-Policy` directive in `infra/nginx.conf`. Rebuild and restart after changes (`make clean && make build && make run`).

---

### 5 · Image size under 10 MB

**What:** The multi-stage build must produce an image under 10 MB. This validates that no build tools leaked into the runtime stage.

**Command:**
```bash
docker image inspect hello-world:0.1.0 --format '{{.Size}}' | \
  awk '{printf "%.2f MB\n", $1/1024/1024}'
```

Or via Makefile:
```bash
make size
```

**Pass criteria:** Output is less than `10.00 MB`.

**Fail action:** Run `docker history hello-world:0.1.0` and look for unexpected `RUN apk add` or `npm install` in the final stage. The runtime stage must contain only `COPY` instructions.

---

### 6 · Process runs as non-root (UID 101)

**What:** The nginx worker process must not run as root. A compromised worker at UID 0 has OS-wide write access.

**Command:**
```bash
docker exec hello id
```

**Pass criteria:** Output contains `uid=101(nginx)`.

**Fail action:** Confirm the base image is `nginx:1.27-alpine-slim` (not `nginx:latest`). The alpine-slim variant creates `nginx` at UID 101. If you used a custom `adduser`, verify the UID.

---

### 7 · Read-only rootfs enforced

**What:** A file write to the container's root filesystem must be refused. An attacker with a remote code execution vulnerability cannot plant persistent files.

**Command:**
```bash
docker exec hello sh -c 'touch /rw-test 2>&1; echo "exit: $?"'
```

**Pass criteria:** Output contains `Read-only file system` AND `exit: 1`.

**Fail action:** Ensure the container was started with `--read-only`. The Makefile's `make run` target includes this flag. Check `docker inspect hello | grep ReadonlyRootfs`.

---

### 8 · Docker healthcheck reports `healthy`

**What:** The `HEALTHCHECK` instruction in the Dockerfile must pass. Orchestrators use this to gate traffic during rollouts.

**Command:**
```bash
docker inspect hello --format='{{.State.Health.Status}}'
```

**Pass criteria:** Output is `healthy`.

**Note:** The container starts in `starting` state for up to `--start-period` seconds (2 s in this project). Wait 10 s after `make run` before checking.

**Fail action:** Check `docker inspect hello --format='{{json .State.Health}}'` for failure logs. Verify the healthcheck URL (`http://127.0.0.1/`) resolves inside the container.

---

### 9 · p95 latency under 50 ms at 50 VUs

**What:** Nginx serving static files must sustain 50 concurrent users with a p95 latency under 50 ms and zero errors.

**Command:**
```bash
make perf
```

Or directly:
```bash
k6 run --env BASE_URL=http://localhost:8080 tests/k6/smoke.js
```

**Pass criteria:**
- `http_req_duration p(95) < 50ms`
- `http_req_failed 0.00%`
- `checks 100.00%`

**Fail action:** High p95 usually means the host is CPU- or memory-constrained. Close other applications. If p95 > 200 ms, check `docker stats hello` during the test for CPU throttling.

---

### 10 · No HIGH or CRITICAL CVEs (Docker Scout)

**What:** The final image must have zero HIGH or CRITICAL known vulnerabilities. This check requires Docker Scout (Docker Desktop ≥ 4.17 or `docker scout` plugin).

**Command:**
```bash
docker scout cves hello-world:0.1.0 --only-severity high,critical
```

**Pass criteria:** Output ends with `0 vulnerabilities found` for HIGH/CRITICAL severities.

**Fail action:** If CVEs are found, run `docker scout recommendations hello-world:0.1.0` for upgrade guidance. The most common fix is bumping `nginx:1.27-alpine-slim` to the latest patch version. Update the `FROM` line in `infra/Dockerfile` and rebuild.

**Alternative (no Scout):** Use `trivy image hello-world:0.1.0 --severity HIGH,CRITICAL` (install: `brew install trivy`).

---

## Full run sequence

```bash
# 1. Build and start
make build
make run

# 2. Manual checks 1–4 (headers)
curl -sI http://localhost:8080/ | grep -iE "x-frame|x-content|content-security"

# 3. Image size check
make size

# 4. Security checks 6 & 7 (uid + readonly)
make inspect

# 5. Healthcheck
docker inspect hello --format='{{.State.Health.Status}}'

# 6. Full E2E automated sweep (checks 1–7)
make test

# 7. Performance test (check 9)
make perf

# 8. CVE scan (check 10, optional)
docker scout cves hello-world:0.1.0 --only-severity high,critical

# 9. Clean up
make stop
```

---

## Pass / Fail summary table

| # | Test | Tool | Pass criteria |
|---|------|------|---------------|
| 1 | HTTP 200 | `curl` | `HTTP/1.1 200 OK` |
| 2 | `X-Frame-Options: DENY` | `curl -I` | header present |
| 3 | `X-Content-Type-Options: nosniff` | `curl -I` | header present |
| 4 | `Content-Security-Policy` present | `curl -I` | header present |
| 5 | Image size < 10 MB | `docker image inspect` | `.Size` < 10 485 760 bytes |
| 6 | Non-root UID | `docker exec id` | `uid=101(nginx)` |
| 7 | Read-only rootfs | `docker exec touch /x` | `Read-only file system` |
| 8 | Healthcheck `healthy` | `docker inspect` | `State.Health.Status = healthy` |
| 9 | p95 < 50 ms @ 50 VUs | k6 | `p(95) < 50ms`, errors = 0 |
| 10 | No HIGH/CRITICAL CVEs | `docker scout cves` | 0 findings |
