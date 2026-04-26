# Trivy

[Aqua Trivy](https://github.com/aquasecurity/trivy) — single binary, scans almost everything: container images, filesystems, git repos, K8s clusters, IaC (Terraform, CloudFormation, K8s YAML, Helm), license compliance, secrets.

## Install

```bash
brew install aquasecurity/trivy/trivy
# or
docker run --rm aquasec/trivy:latest --help
```

## Image scanning

```bash
# Scan a public image
trivy image nginx:1.27-alpine

# Fail CI on HIGH or CRITICAL only, ignore unfixed
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  myregistry.example.com/app:1.2.3

# JSON output for further processing
trivy image -f json -o report.json myapp:1.2.3

# Scan locally-built image without pushing
docker build -t myapp:dev .
trivy image myapp:dev

# Use a specific DB cache (CI optimization)
trivy image --cache-dir /tmp/trivy-cache myapp:1.2.3
```

## Filesystem / repository scanning

```bash
# Scan source code dir for vuln deps + secrets + misconfigs
trivy fs --scanners vuln,secret,misconfig .

# Scan a git repo (clones it)
trivy repo https://github.com/myorg/myapp

# Scan Helm chart
trivy config ./charts/myapp
```

## Kubernetes cluster scanning

Trivy can audit a live cluster — workloads + RBAC + admission misconfigs.

```bash
# Full cluster scan, summary report
trivy k8s --report summary cluster

# Scan a single namespace, all resources
trivy k8s --report all -n production

# Just workloads
trivy k8s --include-kinds=pod,deployment cluster

# Output as SARIF for GitHub code scanning
trivy k8s -f sarif -o k8s.sarif cluster
```

## Suppressions

`.trivyignore` — one CVE per line, optional expiry comment:

```
CVE-2023-12345    # accepted: not exploitable without local user, review 2026-01
CVE-2024-67890
```

Or `trivy.yaml` for richer policy:

```yaml
vulnerability:
  ignore-unfixed: true
  severity: [HIGH, CRITICAL]
secret:
  config: trivy-secret.yaml
```

## CI gating snippet

```yaml
# GitHub Actions
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    format: sarif
    output: trivy.sarif
    severity: HIGH,CRITICAL
    exit-code: '1'
    ignore-unfixed: true
- uses: github/codeql-action/upload-sarif@v3
  with: { sarif_file: trivy.sarif }
```

## Trivy Operator

Run scans continuously inside the cluster — produces `VulnerabilityReport` CRs per workload.

```bash
helm install trivy-operator aqua/trivy-operator -n trivy-system --create-namespace
kubectl get vulnerabilityreports -A
```
