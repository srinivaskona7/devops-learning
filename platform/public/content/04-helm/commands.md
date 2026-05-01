# Helm · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."

## Pane 1 — Triage (*is the release alive?*)

```bash
helm list -A                              # every release in every namespace
helm list -n prod --short                 # release names only, for piping
helm status myapp -n prod                 # STATUS: deployed | failed | pending-upgrade
helm history myapp -n prod                # revisions + who deployed what when
helm get notes myapp -n prod              # the NOTES.txt that was rendered
kubectl get pods -l app.kubernetes.io/instance=myapp -n prod
```

## Pane 2 — Diagnose (*what did Helm actually send?*)

```bash
helm get manifest myapp -n prod           # rendered YAML applied to cluster
helm get values myapp -n prod             # user-supplied values only
helm get values myapp -n prod --all       # defaults + user (full merged view)
helm get hooks myapp -n prod              # hook manifests (pre/post/test)
helm template myapp ./chart -f values.yaml --debug   # dry render, line-numbered errors
helm install myapp ./chart --dry-run --debug | tail -60  # send to apiserver for validation
```

## Pane 3 — Recover (*roll it back, atomically*)

```bash
helm history myapp -n prod                # find the last "deployed" revision
helm rollback myapp 12 -n prod --wait     # copy rev 12 into a new revision
helm rollback myapp 12 -n prod --wait --cleanup-on-fail
helm upgrade --install myapp ./chart -n prod \
  --atomic --wait --timeout 10m -f values.yaml        # atomic upgrade-or-rollback
helm uninstall myapp -n prod --keep-history           # keep history after uninstall
```

## Pane 4 — Author a chart

```bash
helm create hello-app                     # scaffold Chart.yaml + values.yaml + templates/
helm lint ./hello-app                     # static checks
helm lint ./hello-app --strict            # + JSON-schema enforcement
helm template demo ./hello-app -f values-dev.yaml     # render locally
helm template demo ./hello-app --show-only templates/deployment.yaml
helm dependency update ./hello-app        # fetch subcharts into charts/
helm dependency build ./hello-app         # rebuild from Chart.lock
```

## Pane 5 — Repos & search

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update                          # refresh indexes
helm search repo nginx --versions         # list all versions
helm search hub postgres                  # search Artifact Hub
helm show chart bitnami/postgresql        # metadata
helm show values bitnami/postgresql > defaults.yaml
helm show readme bitnami/postgresql | less
helm pull bitnami/postgresql --untar      # download source locally
```

## Pane 6 — Install / Upgrade / Overrides (precedence order right-to-left wins)

```bash
# Upsert pattern — safe for CI
helm upgrade --install myapp bitnami/nginx \
  -n prod --create-namespace \
  -f base.yaml -f prod.yaml \
  --set image.tag=v2.3.1 \
  --atomic --wait --timeout 10m

# String-coerce a numeric-looking value
helm upgrade --install myapp . --set-string image.tag=1.0

# Load a file content into a value (e.g. TLS cert)
helm upgrade --install myapp . --set-file tls.crt=./server.crt

# Keep existing values, only change one knob
helm upgrade myapp . --reuse-values --set image.tag=v3

# Reset to chart defaults + only what you pass now
helm upgrade myapp . --reset-values -f fresh.yaml
```

## Pane 7 — Tests & hooks

```bash
helm test myapp -n prod                   # run all Pods tagged hook=test
helm test myapp -n prod --logs            # stream test-Pod stdout
helm test myapp -n prod --filter name=myapp-test-db   # run one named test

# See what hooks were rendered
helm get hooks myapp -n prod | grep -E "^# Source|helm.sh/hook"
```

## Pane 8 — Package & publish (OCI)

```bash
helm package ./myapp                      # → myapp-0.1.0.tgz
helm repo index . --url https://my.org/charts   # generate index.yaml

# OCI push to GHCR
echo $GH_TOKEN | helm registry login ghcr.io -u $GH_USER --password-stdin
helm push myapp-0.1.0.tgz oci://ghcr.io/$GH_USER/charts

# Install from OCI
helm install myapp oci://ghcr.io/$GH_USER/charts/myapp --version 0.1.0
```

## Pane 9 — Plugins (the three you actually want)

```bash
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/jkroepke/helm-secrets
helm plugin install https://github.com/helm-unittest/helm-unittest

helm diff upgrade myapp ./chart -f values.yaml        # what would change?
helm secrets upgrade --install myapp . -f secrets.yaml
helm unittest ./chart                                 # run tests/*.yaml
```

## Pane 10 — Secrets (SOPS + External Secrets)

```bash
# One-time setup
age-keygen -o ~/.config/sops/age/keys.txt
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: secrets.*\.yaml$
    age: age1xyz...
EOF

# Encrypt / edit / decrypt
sops --encrypt --in-place secrets.yaml
sops secrets.yaml                          # opens $EDITOR, decrypted in memory
sops --decrypt secrets.yaml | less

# Install with encrypted values
helm secrets upgrade --install myapp . -f values.yaml -f secrets.yaml

# Rotate recipients (after adding a new team member's age key)
sops updatekeys secrets.yaml
```

## Pane 11 — Helmfile (many releases as code)

```bash
helmfile init                             # scaffolds helmfile.yaml + .gitignore
helmfile lint                             # lint every chart referenced
helmfile diff                             # show drift vs cluster
helmfile apply                            # diff + upgrade each release
helmfile sync                             # upgrade regardless of diff
helmfile destroy                          # uninstall every declared release
helmfile --environment prod apply         # env-scoped apply

# Selectors — operate on a subset
helmfile -l tier=platform apply           # labels defined in helmfile.yaml
helmfile -l name=cert-manager apply
```

## Pane 12 — Dependencies & subcharts

```bash
# Dependency block in Chart.yaml
# dependencies:
#   - name: postgresql
#     version: "13.x"
#     repository: "https://charts.bitnami.com/bitnami"
#     alias: primary-db
#     condition: primary-db.enabled

helm dependency update ./chart            # download deps → charts/
helm dependency build ./chart             # rebuild from Chart.lock
helm dependency list ./chart              # show versions + status
cat ./chart/Chart.lock                    # pinned versions
```

## Pane 13 — Quick flag reference

| Flag | When to use |
|---|---|
| `--dry-run` | render + validate, do not apply |
| `--debug` | extra output + resolved values |
| `--atomic` | auto-rollback on failure (implies --wait) |
| `--wait` | block until all pods Ready |
| `--timeout 15m` | custom wait deadline |
| `--cleanup-on-fail` | delete hook pods that failed |
| `-f file.yaml` | values file (repeatable, order matters) |
| `--set key=val` | inline override (right-most wins) |
| `--set-string key=val` | force string (avoid float parsing of "1.0") |
| `--set-file key=path` | read file content into a value |
| `--reuse-values` | keep previous values on upgrade |
| `--reset-values` | discard previous values |
| `-n <ns>` | target namespace |
| `--create-namespace` | create ns if missing |
| `--history-max 10` | how many revisions to retain |

## Pane 14 — Emergency one-liners

```bash
# "What changed between revs 7 and 8?"
diff <(helm get manifest myapp --revision 7) <(helm get manifest myapp --revision 8)

# "Which pods belong to release X?"
kubectl get all -l app.kubernetes.io/instance=myapp -A

# "What did Helm store for this release?"
kubectl get secret -n prod -l owner=helm,name=myapp -o name
kubectl get secret sh.helm.release.v1.myapp.v8 -n prod -o json \
  | jq -r '.data.release' | base64 -d | base64 -d | gunzip | jq .

# "Force-delete a stuck release (last resort)"
kubectl delete secret -n prod -l owner=helm,name=myapp
helm uninstall myapp -n prod || true

# "Validate the rendered manifest against K8s schemas"
helm template myapp ./chart -f values.yaml | kubeconform -strict -summary

# "Which chart version is installed where?"
helm list -A -o json | jq -r '.[] | [.name,.namespace,.chart,.app_version] | @tsv'
```

## Pane 15 — Lookup the release secret directly

```bash
# Helm 3 stores each revision as a Secret of type helm.sh/release.v1
kubectl get secret -n prod \
  --field-selector type=helm.sh/release.v1 \
  -l name=myapp \
  -o custom-columns='REV:.metadata.labels.version,STATUS:.metadata.labels.status,AGE:.metadata.creationTimestamp'

# Decode a revision payload
kubectl get secret sh.helm.release.v1.myapp.v5 -n prod -o json \
  | jq -r '.data.release' | base64 -d | base64 -d | gunzip > rev5.json
jq '.info.status, .chart.metadata.version' rev5.json
```

---

**Rule of thumb at 03:00**: `helm history` → `helm rollback <rev>` → `helm status` → go back to sleep.
