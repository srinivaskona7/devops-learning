# Helm 3 Cheatsheet

## Repos
```bash
helm repo add <name> <url>
helm repo update
helm repo list
helm repo remove <name>
helm search repo <term>
helm search hub <term>            # Artifact Hub
```

## Inspect a chart
```bash
helm show chart <chart>
helm show values <chart> > vals.yaml
helm show readme <chart>
helm show all <chart>
helm pull <chart> --untar
```

## Install / Upgrade / Rollback
```bash
helm install <rel> <chart> -n <ns> --create-namespace -f vals.yaml --atomic --wait
helm upgrade --install <rel> <chart> -f vals.yaml --atomic
helm upgrade <rel> <chart> --set image.tag=v2 --reuse-values
helm rollback <rel> <revision>
helm uninstall <rel> -n <ns>
```

## Inspect releases
```bash
helm list -A
helm status <rel> -n <ns>
helm history <rel>
helm get values <rel>             # user values
helm get values <rel> --all       # computed
helm get manifest <rel>           # rendered YAML
helm get notes <rel>
helm get hooks <rel>
```

## Author a chart
```bash
helm create <name>
helm lint <chart>
helm template <rel> <chart> -f vals.yaml
helm install <rel> <chart> --dry-run --debug
helm dependency update <chart>
helm dependency build <chart>
```

## Package & publish
```bash
helm package <chart>
helm repo index . --url https://your.org/charts
helm registry login ghcr.io -u <user> --password-stdin
helm push <chart>-<ver>.tgz oci://ghcr.io/<user>
helm install <rel> oci://ghcr.io/<user>/<chart> --version <ver>
```

## Test
```bash
helm test <rel>
helm test <rel> --logs
```

## Useful flags
| Flag | Use |
|---|---|
| `--dry-run` | render only |
| `--debug` | extra output |
| `--atomic` | rollback on failure |
| `--wait` | wait until Ready |
| `--timeout 10m` | extend wait |
| `-f file.yaml` | values file (repeatable) |
| `--set k=v` | inline override |
| `--set-string k=v` | force string |
| `--set-file k=path` | load file content |
| `--reuse-values` | keep prev values during upgrade |
| `--reset-values` | discard prev values |
| `-n ns` | namespace |
| `--create-namespace` | create ns if missing |

## Plugins
```bash
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/jkroepke/helm-secrets
helm diff upgrade <rel> <chart> -f vals.yaml
helm secrets enc secrets.yaml
```

## Debug a release
```bash
helm get manifest <rel> | kubectl apply --dry-run=client -f -
helm template <rel> <chart> -f vals.yaml | kubeconform -strict
helm history <rel>
helm rollback <rel> <good-revision>
```
