# Best Practices — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# install validators used in the pipeline below
helm plugin install https://github.com/databus23/helm-diff
brew install kubeconform        # or: go install github.com/yannh/kubeconform/cmd/kubeconform@latest
```

## Core commands

```bash
# lint — basic rules
helm lint ./chart

# strict lint — warnings become errors (use this in CI)
helm lint ./chart --strict

# lint against a specific env's values
helm lint ./chart --values values-prod.yaml

# render then schema-validate against the K8s API
helm template ./chart | kubeconform -strict -summary -

# render then server-side dry-run
helm template ./chart | kubectl apply --dry-run=server -f -

# safest install/upgrade flags for production
helm upgrade --install demo ./chart \
  -f values-prod.yaml \
  --atomic --wait --timeout 10m --cleanup-on-fail
```

## Inspect / verify

```bash
# diff the proposed change vs the live release
helm diff upgrade demo ./chart -f values-prod.yaml

# show the actual values used by the running release
helm get values demo --all

# verify NOTES.txt renders cleanly (good UX gate)
helm install demo ./chart --dry-run | sed -n '/NOTES:/,$p'

# exercise a full rollback round-trip — DO this before publishing v1
helm install demo ./chart
helm upgrade demo ./chart --set image.tag=v2
helm rollback demo 1
helm uninstall demo
```

## Cleanup

```bash
helm uninstall demo
```

## One-liners worth memorising

```bash
# values.schema.json — fail fast on bad inputs
helm install demo ./chart -f bad-values.yaml   # errors immediately if schema fails

# never expose secrets in CLI — use --set-file from a secret manager
helm upgrade demo ./chart --set-file tls.crt=./tls.crt --set-file tls.key=./tls.key

# enforce: bump Chart.yaml `version` on EVERY template change
grep '^version:' ./chart/Chart.yaml

# pin image tags as strings to avoid YAML number coercion (e.g. "12345")
helm upgrade demo ./chart --set-string image.tag=12345

# golden validation pipeline (CI):
helm lint ./chart --strict \
  && helm template ./chart -f values-prod.yaml | kubeconform -strict - \
  && helm install demo ./chart --dry-run -f values-prod.yaml
```
