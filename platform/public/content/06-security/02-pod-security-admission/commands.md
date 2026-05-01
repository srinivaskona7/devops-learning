# Pod Security Admission — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# PSA is built-in since v1.25 — confirm the API server has it
kubectl api-resources | grep -i podsecurity
kubectl version --short

# Create a namespace to label
kubectl create namespace app-restricted
kubectl create namespace app-baseline
```

## Apply policies / manifests

```bash
# Restricted: enforce + warn + audit
kubectl label namespace app-restricted \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

# Baseline: enforce baseline, warn at restricted (migration mode)
kubectl label namespace app-baseline \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

# Apply the example manifests
kubectl apply -f namespace-restricted.yaml
kubectl apply -f examples-baseline.yaml
```

## Inspect / verify

```bash
# Show PSA labels on every namespace
kubectl get ns -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn,pod-security.kubernetes.io/audit

# Dry-run a pod against a profile before applying — surfaces violations
kubectl label namespace app-restricted \
  pod-security.kubernetes.io/warn=restricted --overwrite
kubectl apply -f my-pod.yaml --dry-run=server

# Check audit log (on control plane node) for PSA violations
grep pod-security /var/log/kubernetes/audit.log | jq .

# Try to create a privileged pod — should be rejected
kubectl run bad --image=nginx -n app-restricted \
  --overrides='{"spec":{"containers":[{"name":"bad","image":"nginx","securityContext":{"privileged":true}}]}}'
```

## Common operations

```bash
# Migration recipe: warn first, observe, then enforce
kubectl label ns my-ns \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted --overwrite
# ... fix workloads ...
kubectl label ns my-ns \
  pod-security.kubernetes.io/enforce=baseline --overwrite
# ... once clean ...
kubectl label ns my-ns \
  pod-security.kubernetes.io/enforce=restricted --overwrite

# Pin profile version (avoid surprise upgrades)
kubectl label ns my-ns \
  pod-security.kubernetes.io/enforce-version=v1.29 --overwrite

# Exempt kube-system style namespaces
kubectl label ns kube-system pod-security.kubernetes.io/enforce=privileged --overwrite

# Find namespaces with no PSA label at all
kubectl get ns -o json \
  | jq -r '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name'
```

## Cleanup

```bash
# Remove PSA labels (reverts to API-server-wide default, usually 'privileged')
kubectl label namespace app-restricted \
  pod-security.kubernetes.io/enforce- \
  pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/audit-

kubectl delete namespace app-restricted app-baseline
```

## One-liners worth memorising

```bash
# Show every namespace's effective PSA posture in one table
kubectl get ns -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn

# Bulk-label every namespace except kube-system
for ns in $(kubectl get ns -o name | grep -v 'kube-system\|kube-public'); do
  kubectl label "$ns" pod-security.kubernetes.io/warn=restricted --overwrite
done

# Restrict who can patch namespaces (PSA bypass mitigation)
kubectl auth can-i patch namespaces --as=alice
```
