# Walkthrough — main.tf

## `required_providers`
We declare two providers: `kubernetes` (typed CRUD) and `helm` (chart releases). Both are first-party HashiCorp.

## `provider "kubernetes"`
Points at `~/.kube/config`. Whichever context is current is what TF will hit. **Sanity check before apply:**
```bash
kubectl config current-context
kubectl get nodes
```

## `provider "helm"`
Helm needs the same Kube auth — we pass it through. In real configs, both providers' auth blocks usually come from the cluster module's outputs (EKS/GKE), not local kubeconfig.

## `kubernetes_namespace`
Creates the `monitoring` namespace with a `managed_by` label. Note the awkward `metadata[0]` access — `metadata` is a block, so it's exposed as a list of length 1.

## `helm_release`
Installs `kube-prometheus-stack` v65.1.1 from the prometheus-community repo. `set { name, value }` overrides chart values one at a time; for many overrides use `values = [yamlencode({...})]` instead.

`wait = true` blocks `apply` until pods are ready — useful for downstream resources that depend on the chart.

## Common pitfalls
1. **CRDs first, resources second** — Helm chart installs CRDs, but if you have a `kubectl_manifest` referencing those CRDs, Terraform may try to apply it before CRDs exist. Use `depends_on = [helm_release.x]`.
2. **Provider auth chicken-and-egg** — you can't have the K8s provider depend on a cluster created in the same `apply` reliably. Split into two stacks: cluster stack → outputs → addons stack.
3. **Helm release stuck pending-upgrade** — `helm rollback <name> 0 -n <ns>` from outside TF, then re-apply.
