# Packaging & Publishing — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# enable OCI (Helm 3.8+ on by default)
helm version

# login to your OCI registry (GHCR example)
echo "$GITHUB_TOKEN" | helm registry login ghcr.io -u <github-user> --password-stdin
```

## Core commands

```bash
# lint before packaging
helm lint ./hello-app

# package — produces hello-app-<version>.tgz
helm package ./hello-app

# package with explicit chart + app version
helm package ./hello-app --version 0.2.0 --app-version 1.1

# === Classic HTTP repo flow ===
mkdir -p charts/
mv hello-app-0.1.0.tgz charts/
helm repo index charts/ --url https://your.org/charts
# upload charts/ to a static host (GH Pages, S3, nginx)

helm repo add myrepo https://your.org/charts
helm repo update
helm install demo myrepo/hello-app

# === OCI registry flow (recommended) ===
helm push hello-app-0.1.0.tgz oci://ghcr.io/<github-user>
helm install demo oci://ghcr.io/<github-user>/hello-app --version 0.1.0
```

## Inspect / verify

```bash
# render the packaged tgz exactly as a consumer would
helm show all oci://ghcr.io/<github-user>/hello-app --version 0.1.0
helm show values oci://ghcr.io/<github-user>/hello-app --version 0.1.0

# pull the tgz locally for inspection
helm pull oci://ghcr.io/<github-user>/hello-app --version 0.1.0
tar tzf hello-app-0.1.0.tgz | head

# server-side validate
helm template ./hello-app | kubectl apply --dry-run=client -f -

# verify provenance (signed packages)
helm verify hello-app-0.1.0.tgz
```

## Cleanup

```bash
helm registry logout ghcr.io
rm -f hello-app-*.tgz
rm -rf charts/ index.yaml
```

## One-liners worth memorising

```bash
# sign on package, verify on install
helm package ./hello-app --sign --key 'alice@example.com' --keyring ~/.gnupg/secring.gpg
helm install demo ./hello-app-0.1.0.tgz --verify

# regenerate index after adding a new tgz to the repo dir
helm repo index charts/ --url https://your.org/charts --merge charts/index.yaml

# CI: lint → package → push to GHCR
helm lint ./chart && helm package ./chart \
  && helm push ./*.tgz oci://ghcr.io/<github-user>
```
