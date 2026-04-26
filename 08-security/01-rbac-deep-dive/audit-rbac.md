# Auditing RBAC

RBAC entropy is real — every PR that "just needs one more permission" widens blast radius. Audit quarterly.

## kubectl auth can-i

Built into kubectl — single-permission test.

```bash
# Can the current user list pods in default?
kubectl auth can-i list pods --namespace default

# Can a specific service account delete deployments?
kubectl auth can-i delete deployments \
  --as=system:serviceaccount:dev:developer \
  --namespace dev

# Show every verb the current user can perform in a namespace
kubectl auth can-i --list --namespace dev

# Impersonate an OIDC group
kubectl auth can-i create secrets \
  --as=alice@example.com \
  --as-group=platform-developers \
  --namespace dev
```

## rakkess — reverse access matrix

`rakkess` (or `kubectl access-matrix`) shows who can do what for every resource.

```bash
# Install via krew
kubectl krew install access-matrix

# Show all subjects with access to secrets cluster-wide
kubectl access-matrix for secrets

# Show all permissions a service account holds
kubectl access-matrix --sa dev/developer

# Show all permissions a user holds in a namespace
kubectl access-matrix --as alice@example.com -n dev
```

## kubectl-who-can

Reverse lookup: "who can delete pods?"

```bash
kubectl krew install who-can
kubectl who-can delete pods -n dev
kubectl who-can '*' '*'                  # who is effectively cluster-admin?
```

## Find dangerous bindings

```bash
# All ClusterRoleBindings to cluster-admin
kubectl get clusterrolebindings -o json \
  | jq '.items[] | select(.roleRef.name=="cluster-admin") | {name:.metadata.name, subjects:.subjects}'

# Any role with wildcard verbs
kubectl get clusterroles -o json \
  | jq '.items[] | select(.rules[]?.verbs | index("*")) | .metadata.name'

# ServiceAccounts that can create pods (lateral movement vector)
kubectl get clusterrolebindings,rolebindings -A -o json \
  | jq '.items[] | select(.subjects[]?.kind=="ServiceAccount")'
```

## Audit Logging

Enable on the API server (`--audit-policy-file`) — see `09-cluster-hardening/`. Forward to SIEM. Alert on:
- `escalate` / `bind` / `impersonate` verbs
- Creation of ClusterRoleBindings
- Token creation for high-priv ServiceAccounts
- `system:masters` group usage outside break-glass

## Quarterly Review Checklist

1. Export all `(Cluster)RoleBindings` to git
2. Diff against last quarter — justify additions
3. Remove bindings for departed users
4. Find unused ServiceAccounts (no token requests in 90d)
5. Re-attest every `cluster-admin` binding
