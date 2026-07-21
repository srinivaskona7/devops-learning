# Helmfile & ArgoCD — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Helmfile
brew install helmfile
helmfile init                  # installs required plugins (helm-diff, etc.)

# ArgoCD CLI
brew install argocd

# install ArgoCD into a cluster (one-time bootstrap)
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Core commands

### Helmfile (push, CLI from CI)

```bash
# preview — show what would change for an environment
helmfile -e prod diff

# apply (install/upgrade) all releases declared in helmfile.yaml
helmfile -e prod apply

# sync = stricter apply (always runs helm upgrade)
helmfile -e prod sync

# tear down everything declared
helmfile -e prod destroy

# operate on one release only
helmfile -e prod -l name=nginx apply
```

### ArgoCD (pull, in-cluster controller)

```bash
# login to the ArgoCD API
argocd login <argocd-host>

# register the cluster + create app from a Helm chart in git
argocd app create hello \
  --repo https://github.com/org/charts \
  --path charts/hello-app \
  --helm-value-files values-prod.yaml \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace hello \
  --sync-policy automated --auto-prune --self-heal

# trigger a sync manually
argocd app sync hello

# rollback to a previous deployed revision
argocd app rollback hello <history-id>

# apply an ApplicationSet (multi-cluster fan-out)
kubectl apply -f appset.yaml -n argocd
```

## Inspect / verify

```bash
# Helmfile
helmfile -e prod list
helmfile -e prod status
helmfile -e prod template            # render everything locally

# ArgoCD
argocd app list
argocd app get hello
argocd app history hello
argocd app diff hello                # live cluster vs git
kubectl get applications,applicationsets -n argocd
```

## Cleanup

```bash
helmfile -e prod destroy

argocd app delete hello --cascade
kubectl delete -f appset.yaml -n argocd
```

## One-liners worth memorising

```bash
# Helmfile: re-pin to a known git commit by re-running apply against that checkout
git checkout <sha> && helmfile -e prod apply

# ArgoCD: force a refresh from git (bypasses the reconcile interval)
argocd app get hello --refresh
argocd app sync hello --prune

# Decision rule of thumb:
#   few clusters, CI-driven      → Helmfile
#   many clusters, GitOps + UI   → ArgoCD
#   bootstrap ArgoCD with Helmfile, then let ArgoCD own the rest
```
