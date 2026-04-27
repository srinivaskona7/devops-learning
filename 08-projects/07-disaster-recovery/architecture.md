# Architecture — Project 07 Disaster Recovery

## Primary / Secondary topology

```mermaid
flowchart LR
  subgraph Primary["us-east-1 · PRIMARY"]
    direction TB
    EKS1[EKS Cluster]
    PG1[(Postgres primary)]
    ALB1[ALB]
    VEL1[Velero operator]
    EDNS1[ExternalDNS]
    S3P[(S3 backup bucket\nus-east-1)]
  end

  subgraph Secondary["us-west-2 · SECONDARY (warm standby)"]
    direction TB
    EKS2[EKS Cluster]
    PG2[(Postgres standby\nWAL follower)]
    ALB2[ALB]
    VEL2[Velero operator]
    EDNS2[ExternalDNS]
    S3S[(S3 backup bucket\nus-west-2)]
  end

  subgraph Global
    R53[Route53\nweighted + health check]
    CW[CloudWatch\nalarms + dashboards]
    PD[PagerDuty]
  end

  Client((Internet))

  Client --> R53
  R53 -->|"weight=100\n(normal)"| ALB1
  R53 -->|"weight=0 → 100\n(failover)"| ALB2

  ALB1 --> EKS1
  EKS1 --> PG1
  PG1 -->|"WAL archive\nevery 10s"| S3P
  VEL1 -->|"K8s backup\ndaily+15min"| S3P
  EDNS1 -->|"sync LB IPs"| R53

  S3P -->|"CRR async\n≤15s lag"| S3S

  ALB2 --> EKS2
  EKS2 --> PG2
  PG2 -->|"WAL restore\nfrom S3S"| S3S
  VEL2 -->|"read backups"| S3S
  EDNS2 -->|"sync LB IPs"| R53

  CW -->|"alert"| PD
  EKS1 -.->|"metrics"| CW
  EKS2 -.->|"metrics"| CW
  S3P  -.->|"replication lag"| CW
```

## Replication data paths

```mermaid
flowchart TB
  subgraph DataPlane["Data replication paths"]
    WAL["WAL segment (16 MB)\narchive_command every 10s"]
    S3P2["S3 us-east-1\n(source)"]
    CRR["S3 CRR\nasync ≤15s"]
    S3S2["S3 us-west-2\n(destination)"]
    PITR["PITR restore\nrestore_command"]
    PG2B["Postgres secondary\nreplication_lag ≤30s"]

    WAL --> S3P2
    S3P2 --> CRR
    CRR --> S3S2
    S3S2 --> PITR
    PITR --> PG2B
  end

  subgraph AppPlane["K8s state replication paths"]
    BACKUP["Velero backup\nobjects + PVCs"]
    S3PV["S3 us-east-1\nvelero/ prefix"]
    CRRV["S3 CRR\nasync ≤15s"]
    S3SV["S3 us-west-2\nvelero/ prefix"]
    RESTORE["velero restore\n--from-backup"]
    EKS2B["EKS secondary\nall namespaces restored"]

    BACKUP --> S3PV
    S3PV --> CRRV
    CRRV --> S3SV
    S3SV --> RESTORE
    RESTORE --> EKS2B
  end
```

## Failover state machine

```mermaid
stateDiagram-v2
  [*] --> Normal : system start

  Normal : Normal\nPrimary serves 100% traffic\nWAL lag ≤30s\nVelero backups healthy

  Normal --> Degraded : CloudWatch alarm fires\n(latency >2s or error rate >1%)
  Degraded --> Normal : alarm clears within 5 min
  Degraded --> FailoverDecision : alarm persists >5 min\nor primary unreachable

  FailoverDecision : Failover Decision\nOn-call validates:\n- Route53 health check red\n- WAL lag measured\n- Data loss estimate confirmed

  FailoverDecision --> Failover : engineer approves\nor auto-trigger after 10 min

  Failover : Failover In Progress\n- velero restore running\n- WAL-G PITR running\n- DNS TTL=60s set
  Failover --> SecondaryActive : RTO ≤15 min\nsmoke test passes

  SecondaryActive : Secondary Active\nSecondary serves 100% traffic\nPrimary region isolated\nPostmortem scheduled

  SecondaryActive --> FailbackDecision : primary region recovered\n+ all data verified

  FailbackDecision : Failback Decision\n- pg_dump diff: 0 rows diverged\n- Velero backup from secondary\n- DNS pre-lowered to 60s
  FailbackDecision --> Failback : engineer approves

  Failback : Failback In Progress\n- Restore secondary→primary\n- DNS weight shift 0→100\n- Monitor for 30 min
  Failback --> Normal : smoke tests pass\nno regressions
```

## DNS failover sequence

```mermaid
sequenceDiagram
  participant Client
  participant R53 as Route53
  participant HC as Health Check Probe
  participant EKS1 as Primary EKS
  participant EKS2 as Secondary EKS
  participant EDNS as ExternalDNS (secondary)

  Note over Client,EDNS: T=0 — primary region fails

  loop every 10s × 3 failures
    HC->>EKS1: GET /healthz
    EKS1-->>HC: timeout
  end
  HC->>R53: mark primary UNHEALTHY
  R53->>R53: switch weighted record\n100% → secondary

  EKS2->>EKS2: velero restore completes
  EDNS->>EKS2: watch LoadBalancer IP
  EDNS->>R53: upsert A record = secondary LB IP

  Note over Client,EDNS: T+60s — DNS TTL expires

  Client->>R53: resolve api.example.com
  R53-->>Client: secondary IP

  Client->>EKS2: HTTP request
  EKS2-->>Client: 200 OK
```

## Component responsibility matrix

| Component | Primary role | Secondary role | Failover action |
|-----------|-------------|----------------|-----------------|
| Velero | Backup K8s state daily + 15 min | Read replicated backups | Restore latest backup |
| WAL-G | Archive WAL to S3 every 10s | Fetch WAL for standby | PITR restore to T-30s |
| S3 CRR | Source bucket | Destination bucket | Transparent (async) |
| Route53 | Primary A record (w=100) | Secondary A record (w=0) | Flip weight to 100 |
| ExternalDNS | Sync primary LB IPs | Sync secondary LB IPs | Upsert correct IPs |
| CloudWatch | Emit alarm on failure | Monitor restore progress | Alert PagerDuty |
| Postgres | Primary (read+write) | Standby (WAL follower) | Promote to primary |

## Network topology

```
┌─────────────────────────────────────────────────────────┐
│  Route53 (global)                                       │
│  api.example.com                                        │
│  ├── Primary record   weight=100  health-check-id=hc-1  │
│  └── Secondary record weight=0    health-check-id=hc-2  │
└─────────────┬───────────────────────────┬───────────────┘
              │                           │
   ┌──────────▼──────────┐   ┌────────────▼────────────┐
   │  us-east-1           │   │  us-west-2              │
   │  VPC 10.0.0.0/16    │   │  VPC 10.1.0.0/16        │
   │  EKS (3 AZs)        │   │  EKS (3 AZs)            │
   │  RDS Postgres        │   │  RDS Postgres (standby) │
   │  S3 primary bucket  │──▶│  S3 secondary bucket    │
   └─────────────────────┘   └─────────────────────────┘
```
