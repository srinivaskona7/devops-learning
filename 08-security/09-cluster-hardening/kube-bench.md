# kube-bench

CIS Kubernetes Benchmark scanner. Detects ~120 misconfigurations across master, node, etcd, control plane, and policies.

## Run modes

```bash
# 1. As a Job in the cluster (most common)
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs -l app=kube-bench --tail=-1

# 2. On a single node via Docker
docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro \
  -v $(which kubectl):/usr/local/bin/kubectl \
  -v ~/.kube:/.kube -e KUBECONFIG=/.kube/config \
  -t aquasec/kube-bench:latest run --benchmark cis-1.10

# 3. Native binary
kube-bench run --benchmark cis-1.10 --json > result.json
```

## Pin to your CIS version

| K8s version | CIS Benchmark | flag |
|-------------|--------------|------|
| 1.27 | CIS 1.8 | `--benchmark cis-1.8` |
| 1.28-1.29 | CIS 1.9 | `--benchmark cis-1.9` |
| 1.30+ | CIS 1.10 | `--benchmark cis-1.10` |
| EKS | EKS-specific | `--benchmark eks-1.5.0` |
| AKS | AKS-specific | `--benchmark aks-1.5.0` |
| GKE | GKE-specific | `--benchmark gke-1.6.0` |

Managed K8s benchmarks skip control-plane checks (you don't own the master) and add provider-specific items.

## Reading results

Each check has a status:

| Status | Meaning |
|--------|---------|
| PASS | Compliant |
| FAIL | Non-compliant — fix required |
| WARN | Manual verification required (kube-bench can't auto-check) |
| INFO | Informational |

Don't chase 100%. Triage:
1. All `FAIL` → ticket immediately
2. All `WARN` → spot-check then mark as accepted/remediated in a register
3. Re-run weekly in CI / nightly cluster scan

## Suppressions

`--check 5.1.1,5.1.2` to run only specific checks. To suppress noisy ones, maintain a YAML config:

```yaml
# kube-bench-config.yaml
controls:
  id: "1"
  text: "Master Node Security Configuration"
  groups:
    - id: "1.2"
      checks:
        - id: "1.2.6"
          skip: true
          reason: "Managed by EKS, customer cannot modify"
```

## Wire into CI

```yaml
- name: kube-bench
  run: |
    kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
    kubectl wait --for=condition=complete job/kube-bench --timeout=300s
    kubectl logs job/kube-bench > kube-bench.log
    grep -q '\[FAIL\]' kube-bench.log && exit 1 || echo "all pass"
```
