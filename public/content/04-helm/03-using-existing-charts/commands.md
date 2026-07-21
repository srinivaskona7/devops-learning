# Using Existing Charts — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# (optional but highly recommended) helm-diff plugin
helm plugin install https://github.com/databus23/helm-diff
```

## Core commands

```bash
# install
helm install demo bitnami/nginx -n web --create-namespace

# install with values file + ad-hoc overrides
helm install demo bitnami/nginx -f vals.yaml --set replicaCount=3

# upgrade (or install if missing) — idempotent, the CI-friendly pattern
helm upgrade --install demo bitnami/nginx -f vals.yaml -n web

# rollback to a previous revision
helm rollback demo 1 -n web

# uninstall
helm uninstall demo -n web

# uninstall but keep history (allows re-install reusing release name)
helm uninstall demo -n web --keep-history
```

## Inspect / verify

```bash
helm list -A                       # all releases, all namespaces
helm status demo -n web
helm history demo -n web

helm get values demo -n web        # only user-supplied values
helm get values demo -n web --all  # full computed values
helm get manifest demo -n web      # rendered YAML applied to cluster
helm get notes demo -n web

# diff before applying
helm diff upgrade demo bitnami/nginx -f vals.yaml
```

## Cleanup

```bash
helm uninstall demo -n web
kubectl delete ns web
```

## One-liners worth memorising

```bash
# safe preview — render and validate, never apply
helm install demo bitnami/nginx --dry-run --debug | less

# safest upgrade flags: auto-rollback on failure, wait for Ready, clean partials
helm upgrade --install demo bitnami/nginx \
  -f vals.yaml \
  --atomic --wait --timeout 10m --cleanup-on-fail

# diff what an upgrade would do
helm diff upgrade demo bitnami/nginx -f vals.yaml
```
