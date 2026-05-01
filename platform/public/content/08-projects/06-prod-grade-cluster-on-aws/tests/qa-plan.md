# QA Plan — Project 06: Production-Grade EKS Cluster

This plan lets any engineer with AWS credentials and kubectl verify the cluster is production-ready. Execute phases in order. Each phase depends on the previous one passing.

---

## Phase 0 — Pre-apply static checks

Run before every `terraform apply`. These checks catch misconfigurations without spending money.

| # | Check | Command | Pass criteria |
|---|-------|---------|---------------|
| 0.1 | Terraform format | `make fmt` | Exit code 0 — no formatting diffs |
| 0.2 | Terraform validate | `make validate` | "Success! The configuration is valid." |
| 0.3 | TFLint rules | `make tflint` | 0 warnings, 0 errors |
| 0.4 | Checkov security scan | `make checkov` | 0 HIGH or CRITICAL findings |
| 0.5 | tfsec secret scan | `make tfsec` | 0 HIGH findings |
| 0.6 | Cost estimate review | `make cost` | Monthly cost within budget ($250 dev / $1500 prod) |

### Known acceptable checkov suppressions

```ini
# backend-s3.tf.example is intentionally a template — skip checks on example file
CKV_AWS_119  # DynamoDB KMS — example file, not real resource
CKV_AWS_18   # S3 access logging — bootstrap script comment, not real resource
```

---

## Phase 1 — Post-apply infrastructure checks

Run immediately after `make apply-dev`.

| # | Check | Command | Pass criteria |
|---|-------|---------|---------------|
| 1.1 | VPC exists | `aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dev-eks-vpc"` | Returns 1 VPC |
| 1.2 | Subnets — 3 public, 3 private | `aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/dev-eks,Values=shared" \| jq '.Subnets \| length'` | Returns 6 |
| 1.3 | NAT Gateways available | `aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=dev-eks-nat*"` | Status=available for all |
| 1.4 | EKS cluster active | `aws eks describe-cluster --name dev-eks --query 'cluster.status'` | "ACTIVE" |
| 1.5 | OIDC provider registered | `aws iam list-open-id-connect-providers` | Contains cluster OIDC URL |
| 1.6 | KMS key enabled | `aws kms describe-key --key-id alias/dev-eks-eks --query 'KeyMetadata.KeyState'` | "Enabled" |

---

## Phase 2 — Node and pod health

| # | Check | Command | Pass criteria |
|---|-------|---------|---------------|
| 2.1 | Managed nodes ready | `kubectl get nodes` | All nodes STATUS=Ready |
| 2.2 | Node IMDSv2 only | `kubectl debug -it node/NODE_NAME --image=busybox -- curl -s http://169.254.169.254/latest/meta-data/ --header "X-aws-ec2-metadata-token: required"` | Request fails without token (IMDSv2 enforced) |
| 2.3 | CoreDNS running | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | 2/2 Running |
| 2.4 | CoreDNS resolves | `kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default` | Returns cluster IP |
| 2.5 | ALB controller running | `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` | 2/2 Running |
| 2.6 | cert-manager running | `kubectl get pods -n cert-manager` | All pods Running |
| 2.7 | Karpenter running | `kubectl get pods -n karpenter` | 2/2 Running |
| 2.8 | EBS CSI running | `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver` | Controller+node pods Running |
| 2.9 | metrics-server running | `kubectl top nodes` | Returns CPU/memory for all nodes |

---

## Phase 3 — IRSA verification

Verify no pod can call AWS APIs through the node IAM role.

| # | Check | Command | Pass criteria |
|---|-------|---------|---------------|
| 3.1 | Node role has no policies | `aws iam list-attached-role-policies --role-name dev-eks-node-group-role` | Only: AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly |
| 3.2 | Pod cannot use node creds | `kubectl run irsa-test --image=amazon/aws-cli --rm -it --restart=Never -- sts get-caller-identity` | Fails: no credentials / AccessDenied |
| 3.3 | ALB controller IRSA works | `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` | No "credential" errors in logs |
| 3.4 | cert-manager IRSA works | `kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager` | No "unauthorized" errors |
| 3.5 | Karpenter IRSA works | `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter` | No "AccessDenied" errors |

---

## Phase 4 — Functional tests

| # | Check | Command | Pass criteria |
|---|-------|---------|---------------|
| 4.1 | Deploy test workload | `kubectl apply -f tests/fixtures/test-deploy.yaml` | Pod reaches Running within 60s |
| 4.2 | PVC creates gp3 volume | `kubectl apply -f tests/fixtures/test-pvc.yaml` | PVC Bound, pod writes file successfully |
| 4.3 | Volume in correct AZ | `kubectl get pv -o yaml \| grep topology` | AZ matches pod's node AZ |
| 4.4 | Karpenter provisions node | `kubectl apply -f tests/fixtures/burst-deploy.yaml` (50 replicas) | New nodes appear within 90s |
| 4.5 | Karpenter consolidates | Delete burst-deploy, wait 5 min | Extra nodes terminated, events show "consolidation" |
| 4.6 | ALB Ingress creates ALB | `kubectl apply -f tests/fixtures/test-ingress.yaml` | AWS ALB appears in console, health check green |

### test-deploy.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qa-test
spec:
  replicas: 1
  selector:
    matchLabels: { app: qa-test }
  template:
    metadata:
      labels: { app: qa-test }
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          resources:
            requests: { cpu: "100m", memory: "128Mi" }
            limits: { cpu: "200m", memory: "256Mi" }
```

### test-pvc.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: qa-test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ebs-gp3-enc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: qa-pvc-writer
spec:
  containers:
    - name: writer
      image: busybox
      command: ["sh", "-c", "echo 'QA PASS' > /data/test.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - mountPath: /data
          name: data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: qa-test-pvc
```

---

## Phase 5 — Security checks

| # | Check | Tool | Pass criteria |
|---|-------|------|---------------|
| 5.1 | No secrets in TF state | `grep -i "password\|secret\|private_key" $(terraform show -json \| jq -r '.')` | No plaintext secrets |
| 5.2 | EKS audit logs enabled | AWS Console → EKS → Logging | All log types enabled |
| 5.3 | VPC flow logs active | `aws ec2 describe-flow-logs` | State=active for VPC |
| 5.4 | KMS key rotation on | `aws kms get-key-rotation-status --key-id alias/dev-eks-eks` | KeyRotationEnabled=true |
| 5.5 | Nodes use IMDSv2 | `aws ec2 describe-instances --filters "Name=tag:aws:eks:cluster-name,Values=dev-eks" --query 'Reservations[].Instances[].MetadataOptions.HttpTokens'` | All "required" |
| 5.6 | No public node IPs | `aws ec2 describe-instances --filters "Name=tag:aws:eks:cluster-name,Values=dev-eks" --query 'Reservations[].Instances[].PublicIpAddress'` | All null |

---

## Phase 6 — Chaos and resilience

| # | Scenario | Steps | Pass criteria |
|---|----------|-------|---------------|
| 6.1 | Single AZ failure | `aws ec2 create-network-acl-entry --rule-action deny --cidr-block 0.0.0.0/0 ...` on private-a | Traffic routes to AZ-b and AZ-c. No 5xx errors on running test app. |
| 6.2 | Managed node termination | Terminate one system node from AWS console | Replacement node joins. Addon pods reschedule. No Karpenter errors. |
| 6.3 | Spot interruption simulation | `aws ec2 send-spot-instance-interruptions` (CLI preview) | Karpenter drains node proactively. Pod reschedules before 2-min deadline. |
| 6.4 | OOM workload | Deploy pod requesting 10x available memory | Karpenter provisions larger node OR fails scheduling cleanly (no node explosion) |
| 6.5 | Cluster upgrade | Bump cluster_version to 1.31 in tfvars, plan | Plan shows control plane upgrade only. Nodes upgrade via nodegroup update_config. |

---

## Cleanup

```bash
# Remove test fixtures
kubectl delete deployment qa-test
kubectl delete pod qa-pvc-writer
kubectl delete pvc qa-test-pvc

# Destroy dev cluster
make destroy-dev
```

---

## Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Nodes stuck NotReady | VPC CNI not configured | Check `kubectl describe node` and aws-node pods |
| ALB not created | Subnet tags missing | Verify `kubernetes.io/role/elb=1` on public subnets |
| cert-manager fails | Route53 permissions | Check IRSA role trust + cert-manager logs |
| Karpenter no nodes | NodePool constraints too strict | Relax instance type list or AZ requirements |
| PVC stuck Pending | Wrong AZ for WaitForFirstConsumer | Ensure pod's node AZ matches volume AZ |
| IRSA AccessDenied | Wrong OIDC subject in trust | Verify `system:serviceaccount:NAMESPACE:SA` matches actual SA |
