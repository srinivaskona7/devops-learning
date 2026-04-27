# Platform Cost Estimate

**Environment:** Production EKS cluster, us-east-1
**Node type:** m5.xlarge (4 vCPU, 16 GB RAM) — platform components
**Application nodes:** m5.large (2 vCPU, 8 GB RAM) — application workloads
**Pricing:** AWS on-demand (use Savings Plans for -30% to -40% in production)

---

## Compute — EKS Worker Nodes

| Node group | Node type | Count | vCPU | RAM | Monthly cost |
|------------|-----------|-------|------|-----|-------------|
| Platform | m5.xlarge | 3 | 4 | 16GB | $0.192/h × 3 × 730h = **$421** |
| Application | m5.large | 3 | 2 | 8GB | $0.096/h × 3 × 730h = **$210** |
| EKS control plane | — | 1 | — | — | $0.10/h × 730h = **$73** |

**Compute subtotal: $704/month**

_With Savings Plans (3-year, no upfront): ~$422/month_

---

## Storage

| Component | Type | Size | Monthly cost |
|-----------|------|------|-------------|
| Prometheus TSDB | EBS gp3 | 100 GB | $0.08/GB = **$8** |
| Loki object store | S3 | 200 GB | $0.023/GB = **$4.60** |
| Tempo traces | S3 | 100 GB | $0.023/GB = **$2.30** |
| etcd (EKS managed) | EBS gp3 | 20 GB | Included in EKS |
| Vault | EBS gp3 | 10 GB | $0.08/GB = **$0.80** |
| Container registry | ECR | 50 GB | $0.10/GB = **$5** |

**Storage subtotal: $20.70/month**

---

## Networking

| Component | Type | Monthly cost |
|-----------|------|-------------|
| NAT Gateway | Data processed: ~50 GB/mo | $0.045/GB × 50 = **$2.25** |
| NAT Gateway hourly | 1 NAT × 730h | $0.045/h × 730 = **$32.85** |
| Load Balancer (Istio Ingress) | ALB | $0.008/h + $0.008/LCU × 730h = **~$16** |
| Data transfer (inter-AZ) | ~20 GB/mo | $0.01/GB = **$0.20** |
| Route 53 (DNS) | Hosted zone + queries | **$1** |

**Networking subtotal: $52.30/month**

---

## Managed services

| Service | Component | Monthly cost |
|---------|-----------|-------------|
| AWS Secrets Manager | 0 secrets (using Vault instead) | **$0** |
| ACM | TLS certs (free for ALB) | **$0** |
| CloudWatch | Basic metrics (monitoring uses Prometheus) | **~$5** |
| ECR (registry) | 1 repository × 5 images | Included above |

**Managed services subtotal: $5/month**

---

## Platform software (self-hosted, open source — $0 license cost)

| Component | License | Cost |
|-----------|---------|------|
| Argo CD | Apache 2.0 | $0 |
| Argo Rollouts | Apache 2.0 | $0 |
| Istio | Apache 2.0 | $0 |
| Prometheus + Grafana | Apache 2.0 | $0 |
| Loki + Tempo | AGPL v3 | $0 |
| HashiCorp Vault | BSL 1.1* | $0 (self-hosted) |
| External Secrets Operator | Apache 2.0 | $0 |
| Kyverno | Apache 2.0 | $0 |
| Cosign / Sigstore | Apache 2.0 | $0 |
| Chaos Mesh | Apache 2.0 | $0 |
| k6 | AGPL v3 | $0 |
| Backstage | Apache 2.0 | $0 |

*HashiCorp BSL 1.1: free for non-competitive use. For production use by non-competitors: $0. Vault Enterprise: ~$5,000/year if you need enterprise features (HSM, DR, advanced auth).

**Software subtotal: $0/month (open-source stack)**

---

## Total monthly estimate

| Category | Monthly cost |
|----------|-------------|
| Compute (EKS) | $704 |
| Storage | $21 |
| Networking | $52 |
| Managed services | $5 |
| Software licenses | $0 |
| **Total (on-demand)** | **$782/month** |
| **Total (Savings Plans 3yr)** | **~$470/month** |

---

## Cost per service

Assuming 10 services running on the platform:

| Cost item | Per-service allocation |
|-----------|----------------------|
| Platform infrastructure | $782 / 10 = **$78/month** |
| Application nodes (per service) | ~$70/month (2 replicas on m5.large) |
| **Total per service** | **~$148/month** |

Compare to: a single engineer's time managing manual deployments (~$150/hour × 20h/month = $3,000/month). Platform ROI break-even: ~20 services.

---

## Cost optimization levers

| Lever | Estimated savings | Notes |
|-------|-----------------|-------|
| Spot instances (non-platform nodes) | 60–70% on app nodes | Use for stateless application workloads |
| Savings Plans 3-year | 40% on compute | Commit to 3 years for predictable platform |
| Right-size Prometheus storage | -30% storage | Reduce retention from 30d to 15d for non-SLO metrics |
| Loki log filtering | -40% Loki storage | Drop DEBUG logs before ingest |
| Karpenter (node autoscaling) | -20% compute | Scale nodes down to zero during off-hours |
| Spot for Chaos Mesh experiments | -70% on chaos nodes | Chaos nodes can be spot; they're ephemeral |
| **Total potential savings** | **~$350/month** | Realistic for a mature platform |

---

## Local development cost

```
kind cluster (local Docker):   $0/month
All platform components:       $0/month (runs on your laptop)
Required laptop RAM:           16 GB minimum, 32 GB recommended
Docker Desktop:                Free (personal use) / $7/month (commercial)
```

---

## Cloud cost per environment

| Environment | Monthly cost | Notes |
|-------------|-------------|-------|
| Local (kind) | $0 | Laptop resources only |
| Dev/staging (EKS) | ~$200 | Smaller nodes, reduced replicas |
| Production (EKS) | ~$782 | Full HA, on-demand pricing |
| Production (Savings Plans) | ~$470 | 3-year commitment |

---

## Cost alerting

Set AWS billing alerts at:
- $500/month: warning
- $900/month: critical (investigate immediately)

Grafana has an AWS cost datasource (Grafana Cloud) or use `kubecost` for per-namespace cost attribution.

```bash
# Install kubecost for per-service cost visibility
helm install kubecost cost-analyzer/cost-analyzer \
  --namespace kubecost --create-namespace

# Access at: http://localhost:9090 (after port-forward)
```
