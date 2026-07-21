# Creating a Chart — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# scaffold a new chart with the standard structure
helm create mychart

# inspect the scaffolded layout
ls mychart/
ls mychart/templates/
```

## Core commands

```bash
# lint — catches schema, label, and template errors early
helm lint ./mychart

# render templates locally (no cluster contact)
helm template demo ./mychart

# render with a values override
helm template demo ./mychart -f values-dev.yaml

# install dry-run — server-side validation, nothing applied
helm install demo ./mychart --dry-run --debug

# real install
helm install demo ./mychart

# upgrade after edits (bump Chart.yaml version first)
helm upgrade demo ./mychart
```

## Inspect / verify

```bash
helm status demo
helm get manifest demo
helm get notes demo

# port-forward to test the running release
kubectl port-forward svc/demo-mychart 8080:80
curl localhost:8080
```

## Cleanup

```bash
helm uninstall demo
rm -rf ./mychart        # only when discarding the scaffold
```

## One-liners worth memorising

```bash
# lint + render + server-validate in one go
helm lint ./mychart && helm template ./mychart | kubectl apply --dry-run=server -f -

# render a single template file for fast iteration
helm template demo ./mychart -s templates/deployment.yaml

# show what the chart will use as final values (defaults + overrides)
helm template demo ./mychart -f values-dev.yaml | head -50
```
