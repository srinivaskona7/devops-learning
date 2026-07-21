# Values & Overrides — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# typical multi-env layout
ls mychart/
# values.yaml values-dev.yaml values-staging.yaml values-prod.yaml
```

## Core commands

```bash
# install with one values file
helm install app ./mychart -f values-dev.yaml

# layered values — later -f wins over earlier
helm upgrade --install app ./mychart \
  -f values.yaml -f values-prod.yaml -n prod

# scalar override
helm upgrade app ./mychart --set replicaCount=3

# nested override
helm upgrade app ./mychart --set image.tag=v2

# array override
helm upgrade app ./mychart --set 'envs[0].name=FOO,envs[0].value=bar'

# force string (avoids YAML number coercion on numeric tags)
helm upgrade app ./mychart --set-string image.tag=12345

# load a value from a file (good for certs, dockerconfigjson)
helm upgrade app ./mychart --set-file dockerconfig=./config.json
```

## Inspect / verify

```bash
# only user-supplied values
helm get values app

# full computed values (defaults + overrides)
helm get values app --all

# preview the rendered manifest with the chosen values
helm template app ./mychart -f values-prod.yaml | less

# what would change vs the current release (helm-diff plugin)
helm diff upgrade app ./mychart -f values-prod.yaml
```

## Cleanup

```bash
helm uninstall app -n prod
```

## One-liners worth memorising

```bash
# dump a chart's defaults as the starting point for your env file
helm show values bitnami/nginx > values-dev.yaml

# precedence reminder (low → high):
#   chart defaults  <  parent overrides  <  -f file1  <  -f file2  <  --set

# never put secrets in values.yaml — pass via --set-file from CI secret store
helm upgrade --install app ./mychart --set-file tls.key=./tls.key
```
