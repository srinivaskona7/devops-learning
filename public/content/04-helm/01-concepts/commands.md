# Helm Concepts — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# verify helm 3 is the active binary
helm version
helm env
```

## Core commands

```bash
# install a chart → creates release revision 1
helm install demo ./chart

# upgrade with new values → revision 2
helm upgrade demo ./chart --set image.tag=v2

# rollback to a previous revision → stored as a NEW revision
helm rollback demo 1

# delete the release and purge all revisions
helm uninstall demo
```

## Inspect / verify

```bash
# list releases (current namespace)
helm list

# list across all namespaces
helm list -A

# revision history for a release
helm history demo

# the K8s objects helm rendered + applied
helm get manifest demo

# release storage backend (Helm 3 = Secret in release namespace)
kubectl get secret -n <ns> -l owner=helm
kubectl get secret -n <ns> sh.helm.release.v1.demo.v1 -o yaml
```

## Cleanup

```bash
# uninstall release, drop history
helm uninstall demo

# uninstall but keep revision history (re-installable)
helm uninstall demo --keep-history
```

## One-liners worth memorising

```bash
# show current revision number
helm list -o json | jq '.[] | {name, revision}'

# preview without applying
helm install demo ./chart --dry-run --debug | less

# diff what an upgrade would do (requires helm-diff plugin)
helm diff upgrade demo ./chart -f values.yaml

# check release secret = source of truth
kubectl get secret -n default -l owner=helm,name=demo
```
