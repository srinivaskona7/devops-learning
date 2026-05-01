# Architecture — Project 03 · GitOps with Argo CD

## Push-based CI → Git → Argo pull → cluster

```mermaid
flowchart LR
  subgraph Developer
    D["Engineer<br/>laptop"]
  end

  subgraph GitHub
    PR["Pull Request<br/>review + merge"]
    Main["main branch<br/>k8s/overlays/*/"]
  end

  subgraph CI ["GitHub Actions — push-based CI"]
    Lint["Lint +<br/>kustomize build"]
    Test[Unit tests]
    Docker["Docker build<br/>+ push to registry"]
    TagBump["Commit: bump<br/>image tag in overlay"]
    Lint --> Test --> Docker --> TagBump
  end

  subgraph ArgoCD ["Argo CD — pull-based GitOps controller"]
    Poller["Git poller<br/>every 3 min"]
    Diff["Diff engine:<br/>desired vs live"]
    Sync["Sync executor:<br/>kubectl apply"]
    HealthCheck["Health assessor:<br/>Deployment · Service · PDB"]
    Poller --> Diff --> Sync --> HealthCheck
  end

  subgraph Cluster ["kind Cluster — 3 nodes"]
    subgraph CP ["Control Plane"]
      API[kube-apiserver]
    end
    subgraph Workers
      NS1["api-dev<br/>1 replica"]
      NS2["api-staging<br/>2 replicas"]
      NS3["api-prod<br/>3 replicas + PDB"]
    end
    ESO[External Secrets Operator]
    ESO -->|reads SecretStore| FV[fake-vault sidecar]
    ESO -->|writes| KS[K8s Secret]
  end

  D -->|git push / open PR| PR
  PR -->|merge| Main
  Main --> CI
  TagBump --> Main
  Main -->|git clone / fetch| Poller
  Sync -->|kubectl apply| API
  API --> Workers
  HealthCheck -.->|status| Diff
```

---

## Argo CD sync state machine

```mermaid
stateDiagram-v2
  [*] --> Unknown : app registered

  Unknown --> Synced : initial sync succeeds
  Unknown --> OutOfSync : git diverged before first sync

  Synced --> OutOfSync : git commit detected OR manual drift
  OutOfSync --> Syncing : selfHeal=true OR manual sync triggered
  Syncing --> Synced : all resources Applied + Healthy
  Syncing --> SyncFailed : hook error / timeout / resource conflict

  SyncFailed --> OutOfSync : operator resolves error
  Synced --> Degraded : pod CrashLoopBackOff OR OOMKilled
  Degraded --> Synced : pod recovers (restartPolicy RollingUpdate)

  note right of OutOfSync
    Argo CD computes diff:
    desired (git) vs live (etcd)
    Reports: which fields differ,
    which resources are missing/extra
  end note

  note right of Syncing
    Applies resources in wave order:
    wave -1 → wave 0 → wave 1
    Waits for each wave to be Healthy
    before starting the next
  end note
```

---

## Kustomize overlay inheritance

```mermaid
flowchart TB
  Base["k8s/base/
  ─ deployment.yaml    image: url-shortener:latest
  ─ service.yaml       port: 8080
  ─ kustomization.yaml resources: [deployment, service]"]

  Dev["k8s/overlays/dev/
  ─ kustomization.yaml
    bases: [../../base]
    replicas: 1
    newTag: v1.0.0-dev
    configMapGenerator: env=dev"]

  Staging["k8s/overlays/staging/
  ─ kustomization.yaml
    bases: [../../base]
    replicas: 2
    newTag: v1.0.0
    configMapGenerator: env=staging"]

  Prod["k8s/overlays/prod/
  ─ kustomization.yaml
    bases: [../../base]
    replicas: 3
    newTag: v1.0.0
    resources: limits cpu=500m mem=256Mi
  ─ pdb.yaml  minAvailable: 2"]

  Base --> Dev
  Base --> Staging
  Base --> Prod
```

---

## App of Apps topology

```mermaid
flowchart TB
  subgraph Git ["git: infra/argocd/"]
    RootYAML["app-of-apps.yaml<br/>Application CRD"]
    AppsDir["apps/
    api-dev.yaml
    api-staging.yaml
    api-prod.yaml"]
  end

  subgraph ArgoNS ["argocd namespace"]
    RootApp["Application: root-app<br/>watches infra/argocd/apps/"]
    ChildDev[Application: api-dev]
    ChildStag[Application: api-staging]
    ChildProd[Application: api-prod]
    RootApp -->|creates| ChildDev
    RootApp -->|creates| ChildStag
    RootApp -->|creates| ChildProd
  end

  subgraph ClusterNS ["target namespaces"]
    NSdev[api-dev]
    NSstag[api-staging]
    NSprod[api-prod]
  end

  RootYAML -->|kubectl apply once| RootApp
  AppsDir -->|synced by root-app| ArgoNS
  ChildDev -->|syncs overlays/dev| NSdev
  ChildStag -->|syncs overlays/staging| NSstag
  ChildProd -->|syncs overlays/prod| NSprod
```

---

## External Secrets Operator data flow

```mermaid
sequenceDiagram
  participant Git as Git repo
  participant Argo as Argo CD
  participant K8s as kube-apiserver
  participant ESO as ESO controller
  participant Vault as fake-vault sidecar
  participant Pod as url-shortener pod

  Git->>Argo: ExternalSecret CRD committed
  Argo->>K8s: kubectl apply ExternalSecret
  K8s->>ESO: ESO watches ExternalSecret events
  ESO->>Vault: GET /secret/url-shortener/db-creds
  Vault-->>ESO: {"username":"app","password":"s3cr3t"}
  ESO->>K8s: create/update Secret url-shortener-db-creds
  K8s->>Pod: mount Secret as env vars (DATABASE_URL)

  Note over ESO,Vault: ESO re-fetches on TTL expiry<br/>(refreshInterval: 1h)
  Note over Git,Argo: Secret value never written to git.<br/>Only the path reference is in git.
```

---

## Sync wave execution order

```mermaid
gantt
  title Sync Wave Execution — api-prod fresh install
  dateFormat  ss
  axisFormat %Ss

  section Wave -1 (infra)
  Create Namespace api-prod       :done, w1a, 00, 2s
  Apply ResourceQuota             :done, w1b, 02, 1s
  Apply LimitRange                :done, w1c, 03, 1s

  section Wave 0 (workload)
  Apply Deployment (3 replicas)   :done, w2a, 04, 8s
  Apply Service                   :done, w2b, 04, 2s
  Wait: 3/3 pods Running          :active, w2c, 06, 6s

  section Wave 1 (policy)
  Apply PodDisruptionBudget       :done, w3a, 12, 1s
  Apply HorizontalPodAutoscaler   :done, w3b, 13, 1s

  section Health check
  All resources Healthy           :milestone, done, 14, 0s
```

---

## Drift detection and heal timeline

```mermaid
sequenceDiagram
  participant Eng as Engineer
  participant K8s as Cluster (etcd)
  participant Argo as Argo CD poller
  participant Git as Git repo

  Eng->>K8s: kubectl scale deploy api-prod --replicas=0
  Note over K8s: live state: replicas=0

  loop every 3 min (or 30s if patched)
    Argo->>Git: fetch HEAD of main
    Git-->>Argo: desired replicas=3
    Argo->>K8s: GET Deployment api-prod
    K8s-->>Argo: live replicas=0
    Argo->>Argo: diff: DIVERGED
  end

  Argo->>K8s: kubectl apply Deployment (replicas=3)
  K8s->>K8s: Deployment controller: 0→3 pods
  Note over K8s: 3 pods Running, Healthy
  Argo->>Argo: status: Synced Healthy
```

---

## Node layout (kind cluster)

```text
┌─────────────────────────────────────────────────────────────────┐
│  kind cluster: gitops-lab                                       │
│                                                                 │
│  ┌─────────────────────────┐                                    │
│  │  gitops-lab-control-plane                                    │
│  │  kube-apiserver                                              │
│  │  etcd                                                        │
│  │  argocd namespace (all components)                           │
│  │  external-secrets-system namespace                           │
│  └─────────────────────────┘                                    │
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │  gitops-lab-worker   │  │  gitops-lab-worker2  │            │
│  │                      │  │                      │            │
│  │  api-dev (1 pod)     │  │  api-staging (2 pods)│            │
│  │  api-prod (pod 1/3)  │  │  api-prod (pod 2,3)  │            │
│  └──────────────────────┘  └──────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```
