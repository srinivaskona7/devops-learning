# Helm Hooks — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# hook = a manifest with the helm.sh/hook annotation
# place hook templates anywhere under templates/ (e.g. templates/migrate-job.yaml)
```

## Core commands

```bash
# install — runs pre-install → main resources → post-install
helm install demo ./mychart

# upgrade — runs pre-upgrade → diff → post-upgrade
helm upgrade demo ./mychart

# rollback — runs pre-rollback → restore → post-rollback
helm rollback demo 1

# atomic install/upgrade: if any hook (or main resource) fails, auto-rollback
helm upgrade --install demo ./mychart --atomic --timeout 10m

# uninstall — runs pre-delete → delete → post-delete
helm uninstall demo
```

## Inspect / verify

```bash
# hook resources are NOT in the release manifest
helm get manifest demo | grep -i job        # will not show the hook job

# find hook resources directly in the cluster
kubectl get jobs,pods -l helm.sh/hook=pre-upgrade -A
kubectl get jobs -A -o json \
  | jq '.items[] | select(.metadata.annotations["helm.sh/hook"]) | .metadata.name'

# inspect a failed hook job's logs
kubectl logs job/<hook-job-name> -n <ns>
kubectl describe job/<hook-job-name> -n <ns>
```

## Cleanup

```bash
# remove leftover hook resources by hand if delete-policy was missing
kubectl delete job <hook-job-name> -n <ns>

# preferred: set on the hook manifest
#   "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

## One-liners worth memorising

```bash
# common annotations on a hook resource:
#   "helm.sh/hook": pre-upgrade,pre-install
#   "helm.sh/hook-weight": "-5"        # lower runs first
#   "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded

# preview hook ordering and weights
helm template demo ./mychart | grep -E "helm.sh/hook(|-weight):"

# safest upgrade with hooks — auto-rollback if migration fails
helm upgrade --install demo ./mychart --atomic --wait --timeout 10m
```
