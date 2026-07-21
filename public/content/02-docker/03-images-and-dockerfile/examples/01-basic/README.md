# 01-basic — Flask in a slim Python image

## Build
```bash
docker build -t flask-hello:1.0 .
```

## Run
```bash
docker run --rm -p 5000:5000 flask-hello:1.0
curl localhost:5000
# → Hello from Flask in a container!
```

## Observe
- `docker images flask-hello:1.0` → ~125 MB
- `docker history flask-hello:1.0` → see each layer
- `docker inspect flask-hello:1.0 | jq '.[0].Config.User'` → `"appuser"`
- Healthcheck: `docker ps` shows `(healthy)` after ~30s

## Layer structure

<!-- mermaid:rendered -->
<p align="center"><img src="../../../../assets/diagrams/02-docker-03-images-and-dockerfile-examples-01-basic-README-1-ff4a001d.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart TB
  L1[python:3.12-slim base ~80MB] --> L2[LABEL metadata]
  L2 --> L3[ENV vars]
  L3 --> L4[RUN useradd appuser]
  L4 --> L5[WORKDIR /app]
  L5 --> L6[COPY requirements.txt]
  L6 --> L7[RUN pip install ~10MB]
  L7 --> L8[COPY app.py ~1KB]
  L8 --> L9[USER appuser]
  L9 --> L10[EXPOSE / HEALTHCHECK / ENTRYPOINT]
```

</details>
Change `app.py` → only L8+ rebuild. Change `requirements.txt` → L6+ rebuild.
