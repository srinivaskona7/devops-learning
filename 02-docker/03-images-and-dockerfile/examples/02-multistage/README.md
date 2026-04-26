# 02-multistage — Go binary in `scratch`

## Build
```bash
docker build -t go-hello:1.0 .
```

## Run
```bash
docker run --rm -p 8080:8080 go-hello:1.0
curl localhost:8080
# → Hello from Go!
# → Hostname: <id>
```

## Observe
```bash
docker images go-hello:1.0
# → SIZE: ~7 MB  (vs ~350 MB for a naive single-stage golang image)
```

## Layer structure

```mermaid
flowchart LR
  subgraph build_stage[build stage - golang:1.23-alpine]
    B1[go mod download] --> B2[go build -> /out/app]
  end
  subgraph runtime[runtime - scratch]
    R1[ca-certificates.crt] --> R2[/app binary]
  end
  build_stage -.discarded.-> runtime
```

Only the *final stage* ships. The build toolchain (~300 MB of Go) stays behind.

## Try changing it
- Drop `-ldflags="-s -w"` and rebuild — binary grows by ~30%.
- Replace `FROM scratch` with `FROM alpine:3.20` — image grows by ~5 MB but you get a shell for `docker exec`.
