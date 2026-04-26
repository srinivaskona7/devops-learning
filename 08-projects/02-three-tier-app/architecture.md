# Architecture — Three-Tier App

## C4 — Container view

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/08-projects-02-three-tier-app-architecture-1-3335c0ba.svg" alt="diagram" / loading="lazy"></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart TB
  subgraph Internet
    U[User Browser]
  end

  subgraph K8sCluster[Kubernetes Cluster — namespace proj02]
    direction TB
    IG[Ingress<br/>nginx]
    subgraph FE[Frontend tier]
      FE1[nginx + React static<br/>Deployment x2]
    end
    subgraph BE[Backend tier]
      BE1[Node.js Express API<br/>Deployment x2]
    end
    subgraph DATA[Data tier]
      PG[(Postgres 16<br/>StatefulSet x1)]
      PVC[(PVC 5Gi)]
    end
  end

  U -->|HTTPS app.local| IG
  IG -->|/| FE1
  IG -->|/api| BE1
  BE1 -->|5432| PG
  PG --- PVC
```

</details>
## Decisions

| Decision | Why |
|----------|-----|
| StatefulSet for Postgres | Stable network ID + per-replica PVC |
| ClusterIP services | Internal only; ingress is the public edge |
| Single ingress host with path routing | Simpler DNS; no CORS |
| Secrets via Helm values | Demo only — production must use ESO/Vault |
| `topologySpreadConstraints` on FE/BE | Survive single-node failure |

## Request flow (sequence)

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/08-projects-02-three-tier-app-architecture-2-cfc3ca0c.svg" alt="diagram" / loading="lazy"></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
  participant U as User
  participant I as Ingress
  participant F as Frontend
  participant B as Backend
  participant D as Postgres

  U->>I: GET /api/users
  I->>B: route /api → backend svc
  B->>D: SELECT * FROM users
  D-->>B: rows
  B-->>I: 200 JSON
  I-->>U: 200 JSON
```

</details>
## Resource targets

| Component | CPU req | Mem req | CPU lim | Mem lim |
|-----------|---------|---------|---------|---------|
| Frontend  | 50m     | 32Mi    | 200m    | 128Mi   |
| Backend   | 100m    | 128Mi   | 500m    | 512Mi   |
| Postgres  | 250m    | 256Mi   | 1000m   | 1Gi     |
