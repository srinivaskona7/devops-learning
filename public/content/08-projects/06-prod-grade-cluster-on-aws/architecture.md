# Architecture Deep-Dive — Project 06: Production-Grade EKS

This document layers the architecture from the outermost boundary (AWS account) to the innermost (workload pod). Read top-to-bottom to understand how a request travels from a browser to a pod and back.

---

## Layer 1 — Network boundary (VPC)

```mermaid
flowchart TB
  IGW[Internet Gateway]

  subgraph VPC["VPC 10.0.0.0/16"]
    subgraph AZ_A["AZ: us-east-1a"]
      PUB_A[public-a\n10.0.0.0/24]
      PRIV_A[private-a\n10.0.16.0/20]
      NAT_A[NAT GW A]
    end
    subgraph AZ_B["AZ: us-east-1b"]
      PUB_B[public-b\n10.0.1.0/24]
      PRIV_B[private-b\n10.0.32.0/20]
      NAT_B[NAT GW B]
    end
    subgraph AZ_C["AZ: us-east-1c"]
      PUB_C[public-c\n10.0.2.0/24]
      PRIV_C[private-c\n10.0.48.0/20]
      NAT_C[NAT GW C]
    end

    PUB_RTB[Public Route Table\n0.0.0.0/0 → IGW]
    PRIV_RTB_A[Private RT A\n0.0.0.0/0 → NAT-A]
    PRIV_RTB_B[Private RT B\n0.0.0.0/0 → NAT-B]
    PRIV_RTB_C[Private RT C\n0.0.0.0/0 → NAT-C]
  end

  IGW --> PUB_A & PUB_B & PUB_C
  PUB_A --> NAT_A
  PUB_B --> NAT_B
  PUB_C --> NAT_C
  NAT_A --> PRIV_A
  NAT_B --> PRIV_B
  NAT_C --> PRIV_C
  PUB_A & PUB_B & PUB_C --> PUB_RTB
  PRIV_A --> PRIV_RTB_A
  PRIV_B --> PRIV_RTB_B
  PRIV_C --> PRIV_RTB_C
```

**Design notes:**
- Three independent NAT Gateways — if AZ-A fails, AZ-B and AZ-C egress is unaffected.
- Private subnets use /20 (4096 IPs each) to support up to ~37 nodes at 110 pods/node with AWS VPC CNI default mode.
- Public subnets are /24 (256 IPs) — they only host ALB ENIs and NAT EIPs, which need few addresses.

---

## Layer 2 — EKS data plane topology

```mermaid
flowchart LR
  subgraph ManagedNG["Managed Node Group (system tier)"]
    SYS1[t3.medium\nAZ-a]
    SYS2[t3.medium\nAZ-b]
  end
  subgraph KarpenterPool["Karpenter-Managed Nodes (workload tier)"]
    W1[m5.large Spot\nAZ-a]
    W2[m5.xlarge Spot\nAZ-b]
    W3[m6i.large On-Demand\nAZ-c]
  end

  subgraph SystemPods["System Pods (CriticalAddonsOnly toleration)"]
    KARP_POD[Karpenter]
    ALB_POD[ALB Controller]
    CERT_POD[cert-manager]
    EXTDNS_POD[external-dns]
    EBS_POD[EBS CSI Controller]
    METRICS_POD[metrics-server]
  end

  subgraph WorkloadPods["Workload Pods (no toleration needed)"]
    APP1[app-v1 pod]
    APP2[app-v1 pod]
    APP3[app-v2 pod]
  end

  ManagedNG --> SystemPods
  KarpenterPool --> WorkloadPods
```

**Taint isolation**: managed nodes carry `CriticalAddonsOnly=true:NoSchedule`. Only pods with the matching toleration (addons) land there. Workload pods go exclusively to Karpenter nodes.

---

## Layer 3 — IAM + OIDC trust chain

```mermaid
flowchart TD
  EKS_CLUSTER[EKS Cluster] -->|publishes JWKS at| OIDC_URL[OIDC Issuer URL]
  OIDC_URL -->|registered as| OIDC_PROVIDER[aws_iam_openid_connect_provider]
  OIDC_PROVIDER -->|trusted by| ROLE_A[IRSA Role: ALB Controller]
  OIDC_PROVIDER -->|trusted by| ROLE_B[IRSA Role: cert-manager]
  OIDC_PROVIDER -->|trusted by| ROLE_C[IRSA Role: EBS CSI]
  OIDC_PROVIDER -->|trusted by| ROLE_D[IRSA Role: Karpenter]
  OIDC_PROVIDER -->|trusted by| ROLE_E[IRSA Role: external-dns]

  ROLE_A -->|annotated on| SA_ALB[ServiceAccount: aws-load-balancer-controller]
  ROLE_B -->|annotated on| SA_CERT[ServiceAccount: cert-manager]
  ROLE_C -->|annotated on| SA_EBS[ServiceAccount: ebs-csi-controller-sa]
  ROLE_D -->|annotated on| SA_KARP[ServiceAccount: karpenter]
  ROLE_E -->|annotated on| SA_DNS[ServiceAccount: external-dns]

  SA_ALB -->|mounted in| POD_ALB[ALB Controller Pod]
  SA_CERT -->|mounted in| POD_CERT[cert-manager Pod]
  SA_EBS -->|mounted in| POD_EBS[EBS CSI Pod]
  SA_KARP -->|mounted in| POD_KARP[Karpenter Pod]
  SA_DNS -->|mounted in| POD_DNS[external-dns Pod]
```

---

## Layer 4 — Request path (browser → pod)

```mermaid
sequenceDiagram
  participant Browser
  participant R53 as Route 53
  participant ALB as AWS ALB
  participant TG as Target Group
  participant Pod as App Pod (private IP)
  participant EBS as EBS Volume

  Browser->>R53: DNS lookup app.example.com
  R53-->>Browser: ALB DNS A record
  Browser->>ALB: HTTPS :443 (TLS terminated at ALB)
  ALB->>ALB: ACM cert validation + SSL offload
  ALB->>TG: HTTP :8080 (target-type: ip, pod IP direct)
  TG->>Pod: HTTP request forwarded
  Pod->>EBS: read/write persistent data
  EBS-->>Pod: data
  Pod-->>TG: HTTP response
  TG-->>ALB: response
  ALB-->>Browser: HTTPS response
```

**No extra hops.** `target-type: ip` means the ALB routes directly to pod IPs. There is no NodePort or kube-proxy in the request path.

---

## Layer 5 — Karpenter provisioning loop

```mermaid
stateDiagram-v2
  [*] --> Watching: controller starts
  Watching --> Evaluating: unschedulable pod detected
  Evaluating --> Provisioning: NodePool match found
  Provisioning --> Launching: EC2 RunInstances API call
  Launching --> Registering: node bootstrap completes
  Registering --> Ready: node joins cluster
  Ready --> Watching: pod scheduled
  Ready --> Consolidating: node underutilized > consolidateAfter
  Consolidating --> Draining: cordon + evict pods
  Draining --> Terminating: all pods evicted
  Terminating --> [*]: EC2 TerminateInstances
```

---

## Layer 6 — cert-manager TLS lifecycle

```mermaid
flowchart TD
  CR[Certificate resource\ncreated by Helm/kubectl] --> CM[cert-manager controller]
  CM --> ORDER[Create ACME Order\n at Let's Encrypt]
  ORDER --> CHALLENGE[DNS-01 Challenge\nrequired]
  CHALLENGE --> R53_TXT[Create TXT record\n_acme-challenge.app.example.com\nin Route 53]
  R53_TXT --> LE_VERIFY[Let's Encrypt\nverifies DNS record]
  LE_VERIFY --> ISSUE[Certificate issued\n90-day validity]
  ISSUE --> SECRET[Stored in\nKubernetes Secret]
  SECRET --> RENEWAL[cert-manager watches\n30 days before expiry]
  RENEWAL --> ORDER
```

---

## Layer 7 — EBS CSI volume lifecycle

```mermaid
stateDiagram-v2
  [*] --> PVCPending: PVC created (WaitForFirstConsumer)
  PVCPending --> PodScheduled: scheduler picks node (AZ known)
  PodScheduled --> VolumeCreating: CSI CreateVolume in same AZ
  VolumeCreating --> Attaching: CSI AttachVolume to instance
  Attaching --> Mounted: CSI NodeStageVolume + NodePublishVolume
  Mounted --> InUse: pod reads/writes
  InUse --> Detaching: pod deleted / node drain
  Detaching --> Available: volume detached, PV retained
  Available --> [*]: manual PV delete → volume delete
```

---

## Security boundaries summary

```text
┌──────────────────────────────────────────────────────────────────┐
│  AWS Account Boundary                                            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  VPC Boundary — all EKS traffic is private                 │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  EKS Cluster — private API endpoint                  │  │  │
│  │  │  ┌────────────────────┐  ┌──────────────────────┐   │  │  │
│  │  │  │  System Nodes      │  │  Workload Nodes      │   │  │  │
│  │  │  │  (managed, tainted)│  │  (Karpenter, spot)   │   │  │  │
│  │  │  │  • ALB Controller  │  │  • App pods          │   │  │  │
│  │  │  │  • cert-manager    │  │  • IRSA per pod      │   │  │  │
│  │  │  │  • Karpenter       │  │  • No node IAM       │   │  │  │
│  │  │  └────────────────────┘  └──────────────────────┘   │  │  │
│  │  │  Node IAM role: zero AWS permissions                  │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

| Boundary | Control |
|----------|---------|
| Internet → VPC | Security Groups + NACLs |
| Public → Private subnet | No route except through NAT (outbound) / ALB (inbound) |
| Pod → AWS APIs | IRSA only — node instance profile has no permissions |
| Pod → Pod | Network Policy (recommend Calico or VPC CNI network policy) |
| Control plane → nodes | EKS-managed ENI in node subnet, port 443 + 10250 |
