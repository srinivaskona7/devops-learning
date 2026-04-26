# 11 — RBAC

> RBAC = Role-Based Access Control. **Who** (subject) can do **what** (verb) on **which** resource, in **which** scope.

## The 4 building blocks

```mermaid
flowchart LR
  SUB[Subject<br/>User / Group / ServiceAccount] --> RB[RoleBinding]
  RB --> ROLE[Role<br/>verbs + resources]
  SUB2[Subject] --> CRB[ClusterRoleBinding]
  CRB --> CROLE[ClusterRole<br/>cluster-wide verbs]
  RB -.namespaced.-> NS[Namespace]
  CRB -.cluster-wide.-> CL[Cluster]
```

| Object | Scope | Pairs with |
|--------|-------|------------|
| **Role** | One namespace | RoleBinding |
| **ClusterRole** | Cluster-wide | ClusterRoleBinding (cluster) OR RoleBinding (single ns) |
| **RoleBinding** | One namespace | Role or ClusterRole |
| **ClusterRoleBinding** | Cluster-wide | ClusterRole only |

## ServiceAccount

Workloads (pods) authenticate to the API server using a **ServiceAccount**. Every namespace has a `default` SA — but you should make purpose-specific ones.

```mermaid
flowchart LR
  POD[Pod] -->|projected token| API[kube-apiserver]
  POD -.uses.- SA[ServiceAccount<br/>app-sa]
  SA -->|RoleBinding| R[Role<br/>read configmaps]
```

## Apply & observe

```bash
kubectl apply -f rbac-example.yaml

# Check what the SA can do
kubectl auth can-i list configmaps --as=system:serviceaccount:default:app-reader
# → yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:app-reader
# → no

# Run a pod AS that SA and try
kubectl run test --rm -it --image=bitnami/kubectl --restart=Never \
  --overrides='{"spec":{"serviceAccountName":"app-reader"}}' -- \
  kubectl get configmaps
```

## Common ClusterRoles (built-in)

| ClusterRole | Use |
|-------------|-----|
| `cluster-admin` | God mode — never use except break-glass |
| `admin` | Full RW in a namespace (via RoleBinding) |
| `edit` | Modify objects in a namespace, no RBAC |
| `view` | Read-only in a namespace |

## Cleanup

```bash
kubectl delete -f rbac-example.yaml
```

## Gotchas

> ⚠️ **RBAC is additive.** No deny rules — if any binding grants access, you have it. Audit with `kubectl auth can-i --list --as=...`.

> ⚠️ **Don't bind `cluster-admin` to a SA.** That SA token in a pod = full cluster compromise from a single RCE.

> ⚠️ **`automountServiceAccountToken: false`** on Pods/SAs that don't call the API. Reduces blast radius.

> ⚠️ **Wildcards (`*`) in resources/verbs are dangerous.** Be explicit.

> ⚠️ **Cloud IAM ≠ K8s RBAC.** EKS/GKE/AKS map cloud identities to K8s users/groups via aws-auth ConfigMap, OIDC, or AAD — but RBAC still gates everything inside the cluster.

## Reference

- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
