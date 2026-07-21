# Compliance — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Audit policy on the API server
sudo cp audit-policy.yaml /etc/kubernetes/audit-policy.yaml
sudo chmod 0600 /etc/kubernetes/audit-policy.yaml

# Wire into kube-apiserver static pod manifest
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
# - --audit-log-path=/var/log/kubernetes/audit.log
# - --audit-log-maxage=30
# - --audit-log-maxbackup=10
# - --audit-log-maxsize=100

# Compliance-friendly tools
brew install aquasecurity/trivy/trivy
docker pull aquasec/kube-bench:latest
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
helm install falco falcosecurity/falco -n falco --create-namespace
```

## Apply policies / manifests

```bash
# CIS evidence (kube-bench Job)
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Vulnerability evidence (Trivy operator continuously scans)
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  -n trivy-system --create-namespace

# Policy attestation (Kyverno produces PolicyReports — direct evidence)
kubectl apply -f /path/to/kyverno-baseline-policies/
```

## Inspect / verify

```bash
# Audit log — who did what
sudo tail -f /var/log/kubernetes/audit.log | jq .

# Filter audit log for sensitive verbs on Secrets
sudo jq 'select(.objectRef.resource=="secrets" and .verb!="list")' \
  /var/log/kubernetes/audit.log

# CIS evidence
kubectl logs job.batch/kube-bench > cis-evidence-$(date +%F).txt

# CVE evidence
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
trivy k8s --report all cluster > vuln-evidence-$(date +%F).json

# Policy evidence
kubectl get policyreport -A -o json > policy-evidence-$(date +%F).json
kubectl get clusterpolicyreport -o json

# Falco runtime evidence (forward to S3/Splunk for retention)
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=24h > runtime-events.log

# Encryption-at-rest evidence
sudo grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml
```

## Common operations

```bash
# RBAC review — every binding to admin / cluster-admin
kubectl get clusterrolebindings -o json \
  | jq '.items[] | select(.roleRef.name | test("admin"))'

# NetworkPolicy coverage report
kubectl get netpol -A -o json \
  | jq '.items | group_by(.metadata.namespace) | map({ns: .[0].metadata.namespace, count: length})'

# mTLS coverage (Istio)
istioctl authn tls-check <pod>.<ns>

# Image signing coverage
for img in $(kubectl get pods -A -o jsonpath='{..image}' | tr ' ' '\n' | sort -u); do
  cosign verify "$img" \
    --certificate-identity-regexp 'https://github.com/org/.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    >/dev/null 2>&1 && echo "OK $img" || echo "UNSIGNED $img"
done
```

## Cleanup

```bash
# Audit log rotation handled by --audit-log-maxbackup
sudo rm -f /var/log/kubernetes/audit.log.*

# Tooling
helm uninstall trivy-operator -n trivy-system
kubectl delete job kube-bench
```

## One-liners worth memorising

```bash
# Daily evidence collection script (cron-friendly)
DATE=$(date +%F); mkdir -p evidence/$DATE
kubectl logs job.batch/kube-bench > evidence/$DATE/cis.txt
kubectl get vulnerabilityreports -A -o json > evidence/$DATE/vulns.json
kubectl get policyreport -A -o json > evidence/$DATE/policies.json
kubectl get clusterrolebindings -o yaml > evidence/$DATE/rbac.yaml

# Top-volume audit events (tune --audit-policy)
sudo jq -r '.objectRef.resource' /var/log/kubernetes/audit.log \
  | sort | uniq -c | sort -rn | head

# Confirm secrets ARE logged at Metadata only (never RequestResponse)
sudo jq 'select(.objectRef.resource=="secrets") | .level' \
  /var/log/kubernetes/audit.log | sort -u
```
