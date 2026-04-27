# COST.md — Project 06: Production-Grade EKS Cluster

Monthly cost estimates for dev and production configurations. All prices are AWS us-east-1 on-demand unless noted.

---

## Dev environment estimate

| Resource | Config | Unit price | Monthly cost |
|----------|--------|-----------|-------------|
| EKS control plane | 1 cluster | $0.10/hr | **$73** |
| Managed nodes | 2 × t3.medium | $0.0416/hr each | **$61** |
| NAT Gateway | 1 (single AZ) | $0.045/hr + $0.045/GB | **~$33** |
| EBS volumes (nodes) | 2 × 50 GB gp3 | $0.08/GB-month | **$8** |
| EBS volumes (PVCs) | variable | $0.08/GB-month | **$5–20** |
| Karpenter nodes | t3.large Spot × 2 avg | ~$0.025/hr (70% off) | **~$37** |
| CloudWatch logs | VPC flow + EKS audit | ~$0.50/GB ingested | **~$15** |
| ALB | 1 ALB | $0.0225/hr + LCU | **~$20** |
| Route53 | 1 hosted zone | $0.50/zone | **$0.50** |
| **Dev total** | | | **~$250/month** |

---

## Production environment estimate

| Resource | Config | Unit price | Monthly cost |
|----------|--------|-----------|-------------|
| EKS control plane | 1 cluster | $0.10/hr | **$73** |
| Managed nodes | 3 × m5.xlarge | $0.192/hr each | **$415** |
| NAT Gateways | 3 (one per AZ) | $0.045/hr each | **$99** |
| EBS volumes (nodes) | 3 × 50 GB gp3 | $0.08/GB-month | **$12** |
| EBS volumes (PVCs) | 500 GB average | $0.08/GB-month | **$40** |
| Karpenter nodes | m5.xlarge Spot × 5 avg | ~$0.064/hr (67% off) | **~$230** |
| CloudWatch logs | VPC flow + EKS audit | ~$0.50/GB ingested | **~$40** |
| KMS | 1 key + API calls | $1/key + $0.03/10K API | **~$5** |
| ALBs | 2 ALBs (prod + internal) | $0.0225/hr + LCU | **~$50** |
| Route53 | 1 hosted zone | $0.50/zone + queries | **~$5** |
| Data transfer | cross-AZ + internet | $0.01–0.09/GB | **~$30** |
| **Prod total** | | | **~$1,000/month** |

---

## Cost breakdown by category

```
Dev (~$250/month)
  Control plane: 29%  ████████████████████████████▌
  Compute:       39%  ███████████████████████████████████████
  Networking:    13%  █████████████
  Storage:       11%  ███████████
  Observability:  8%  ████████

Prod (~$1,000/month)
  Control plane:  7%  ███████
  Compute:       64%  ████████████████████████████████████████████████████████████████
  Networking:    15%  ███████████████
  Storage:        5%  █████
  Observability:  4%  ████
  Other:          5%  █████
```

---

## Cost-cutting tips

### Immediate savings (no architecture change)

| Tip | Savings | Trade-off |
|-----|---------|-----------|
| Use Spot for Karpenter nodes (already enabled) | 60–70% on compute | Spot interruption risk (handled by Karpenter drain) |
| Enable `consolidationPolicy: WhenUnderutilized` (already enabled) | 15–25% | Slight latency on scale-up after consolidation |
| Use single NAT GW in dev | $66/month | Dev only — AZ failure takes all egress |
| Set Karpenter CPU/memory limits | Prevents runaway scaling | Must size correctly for peak load |
| Use S3 for logs instead of CloudWatch | 40–60% on logging | Harder to search without Athena |

### Medium-effort savings

| Tip | Savings | Notes |
|-----|---------|-------|
| Use AL2023 Graviton instances (m7g family) | 20% vs x86 | Requires arm64 container images |
| Enable Karpenter Spot diversification (already configured) | Increases Spot availability | More instance types = less interruption |
| Use Reserved Instances for managed nodes | 30–40% on baseline | 1-year commitment |
| Enable EBS gp3 vs gp2 (already gp3) | ~20% on EBS | gp3 is cheaper AND faster |
| Reduce CloudWatch log retention (currently 30 days) | 40% on logs | Compliance may require longer retention |

### Architecture-level savings

| Tip | Savings | Complexity |
|-----|---------|-----------|
| Use Fargate for non-critical workloads | Eliminates idle node cost | No DaemonSets, different pricing model |
| Consolidate multiple small clusters | 1 control plane ($73/month) | More complex RBAC, blast radius |
| Use VPC Lattice instead of ALB per service | Reduces ALB count | Preview service, not GA everywhere |
| Implement cost allocation tags (already in tfvars) | No direct savings | Enables per-team chargeback |

---

## Infracost

Generate a live estimate:

```bash
make cost       # dev
make cost-prod  # prod
```

Track cost over time with infracost diff between environments:

```bash
make cost-diff
```

---

## Cost anomaly alerts

Set up AWS Cost Anomaly Detection to alert when costs deviate from baseline:

```bash
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "eks-cluster-monitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "eks-spike-alert",
    "MonitorArnList": ["MONITOR_ARN"],
    "Subscribers": [{
      "Address": "your-team@example.com",
      "Type": "EMAIL"
    }],
    "Threshold": 50,
    "Frequency": "DAILY"
  }'
```

This alerts when EKS or EC2 spending increases by $50/day above baseline — catches runaway Karpenter scaling or forgotten load tests.
