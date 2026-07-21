# Chart Dependencies — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# add the repos the dependencies live in
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# declare deps in Chart.yaml under `dependencies:` then run `dependency update`
```

## Core commands

```bash
# resolve + download deps into charts/, write Chart.lock
helm dependency update ./umbrella

# list declared deps and their pinned status
helm dependency list ./umbrella

# rebuild charts/ strictly from Chart.lock (use this in CI for reproducibility)
helm dependency build ./umbrella

# install the umbrella as a single release
helm install stack ./umbrella -n stack --create-namespace

# upgrade after bumping a sub-chart version in Chart.yaml
helm dependency update ./umbrella
helm upgrade stack ./umbrella -n stack
```

## Inspect / verify

```bash
# verify deps are vendored
ls ./umbrella/charts/
cat ./umbrella/Chart.lock

# render to confirm subchart values are wired correctly
helm template stack ./umbrella | less

# confirm conditions are honoured (subchart should disappear when disabled)
helm template stack ./umbrella --set redis.enabled=false | grep -i redis
```

## Cleanup

```bash
helm uninstall stack -n stack
kubectl delete ns stack

# wipe vendored sub-charts (forces fresh `dependency update`)
rm -rf ./umbrella/charts ./umbrella/Chart.lock
```

## One-liners worth memorising

```bash
# disable a subchart at install time via its `condition` key
helm install stack ./umbrella --set postgresql.enabled=false

# toggle a group of subcharts via `tags`
helm install stack ./umbrella --set tags.cache=false

# subchart values MUST be nested under the dep `name` (or `alias`)
# parent values.yaml:
#   postgresql:
#     auth:
#       postgresPassword: changeme
```
