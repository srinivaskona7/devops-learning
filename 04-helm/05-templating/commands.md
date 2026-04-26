# Templating — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# work inside an existing chart
cd mychart/
ls templates/
```

## Core commands

```bash
# render every template to stdout (no cluster contact)
helm template demo ./

# render with custom values
helm template demo ./ -f values-dev.yaml --set image.tag=v2

# render a single template file
helm template demo ./ -s templates/deployment.yaml

# render and pipe into kubectl for server-side validation
helm template demo ./ | kubectl apply --dry-run=server -f -

# install dry-run prints rendered YAML AND validates against the API server
helm install demo ./ --dry-run --debug
```

## Inspect / verify

```bash
# lint includes template parse errors
helm lint ./

# show rendered notes (NOTES.txt is templated)
helm install demo ./ --dry-run | sed -n '/NOTES:/,$p'

# inspect built-in objects via debug output
helm template demo ./ --debug 2>&1 | head -40

# verify a specific template renders correctly with prod values
helm template demo ./ -f values-prod.yaml -s templates/configmap.yaml
```

## Cleanup

```bash
# nothing to clean — `helm template` does not touch the cluster
```

## One-liners worth memorising

```bash
# render + diff against the live release (requires helm-diff)
helm diff upgrade demo ./ -f values-prod.yaml

# spot whitespace / indent bugs by rendering only one resource
helm template demo ./ -s templates/deployment.yaml | less

# trigger pod restart on configmap change — checksum annotation pattern
# (template snippet — drop into pod spec)
# checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}

# always prefer `include` over `template` so output can be piped:
# {{ include "mychart.labels" . | nindent 4 }}
```
