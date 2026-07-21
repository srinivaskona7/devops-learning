# RBAC Deep Dive — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Create a namespace to scope the developer role to
kubectl create namespace dev-team

# Create a ServiceAccount for a workload
kubectl create serviceaccount app-sa -n dev-team

# Create a (human) user context via certificate or OIDC — example using a test SA token
kubectl create token app-sa -n dev-team --duration=1h
```

## Apply policies / manifests

```bash
# Namespace-scoped Role + RoleBinding
kubectl apply -f role-developer.yaml
kubectl create rolebinding dev-binding \
  --role=developer \
  --serviceaccount=dev-team:app-sa \
  -n dev-team

# Cluster-wide read-only role
kubectl apply -f clusterrole-readonly.yaml
kubectl create clusterrolebinding readonly-binding \
  --clusterrole=readonly \
  --user=alice@example.com

# Aggregated ClusterRole — rules merge into the built-in 'view'
kubectl label clusterrole monitoring-aggregate \
  rbac.authorization.k8s.io/aggregate-to-view=true
```

## Inspect / verify (kubectl auth can-i)

```bash
# Can the current user do X?
kubectl auth can-i create deployments -n dev-team
kubectl auth can-i delete secrets --all-namespaces
kubectl auth can-i '*' '*' --all-namespaces        # check for cluster-admin

# Impersonate to test another subject's access
kubectl auth can-i list pods -n dev-team \
  --as=system:serviceaccount:dev-team:app-sa

kubectl auth can-i get secrets -n prod \
  --as=alice@example.com --as-group=devs

# Show all permissions for a subject
kubectl auth can-i --list --as=system:serviceaccount:dev-team:app-sa -n dev-team

# Inspect roles and bindings
kubectl get roles,rolebindings -n dev-team
kubectl get clusterroles,clusterrolebindings
kubectl describe clusterrole view
kubectl describe rolebinding dev-binding -n dev-team

# Find every binding that references a ClusterRole
kubectl get clusterrolebinding -o json \
  | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```

## Common operations

```bash
# Disable automount of SA token on pods that don't talk to API
kubectl patch serviceaccount app-sa -n dev-team \
  -p '{"automountServiceAccountToken": false}'

# Find pods still using the default SA
kubectl get pods --all-namespaces \
  -o jsonpath='{range .items[?(@.spec.serviceAccountName=="default")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'

# List every subject with cluster-admin
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]?.name'

# Generate a kubeconfig for a SA token
SA_TOKEN=$(kubectl create token app-sa -n dev-team --duration=24h)
kubectl config set-credentials app-sa --token="$SA_TOKEN"
```

## Cleanup

```bash
kubectl delete rolebinding dev-binding -n dev-team
kubectl delete role developer -n dev-team
kubectl delete clusterrolebinding readonly-binding
kubectl delete clusterrole readonly monitoring-aggregate
kubectl delete serviceaccount app-sa -n dev-team
kubectl delete namespace dev-team
```

## One-liners worth memorising

```bash
# Audit: every subject with any wildcard verb
kubectl get clusterroles -o json \
  | jq -r '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'

# Who can read secrets cluster-wide?
kubectl auth can-i get secrets --all-namespaces --as=<user>

# Impersonate while editing — confirms perms before granting them
kubectl get pods -n prod --as=system:serviceaccount:dev-team:app-sa

# Dump effective roles for a SA into YAML for review
kubectl get rolebindings,clusterrolebindings -A -o json \
  | jq '.items[] | select(.subjects[]?.name=="app-sa")'
```
