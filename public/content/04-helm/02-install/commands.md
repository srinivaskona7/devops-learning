# Install Helm & Repos — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# macOS
brew install helm

# Linux (script)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Linux (apt)
curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm

# Windows
choco install kubernetes-helm
winget install Helm.Helm
```

## Core commands

```bash
# add the most useful public repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io

# refresh the local index (do this before searching)
helm repo update

# search a configured repo
helm search repo nginx
helm search repo bitnami/postgresql --versions | head

# search Artifact Hub (no repo add required)
helm search hub wordpress
```

## Inspect / verify

```bash
helm version
helm env                           # paths: cache, config, data
helm repo list

# inspect a chart without installing
helm show chart bitnami/nginx
helm show values bitnami/nginx > /tmp/nginx-values.yaml
helm show readme bitnami/nginx
helm show all bitnami/nginx
```

## Cleanup

```bash
# remove a repo from local config
helm repo remove bitnami

# wipe the local chart cache
rm -rf "$(helm env HELM_CACHE_HOME)"
```

## One-liners worth memorising

```bash
# zsh completion
helm completion zsh > "${fpath[1]}/_helm"

# bash completion (current shell)
source <(helm completion bash)

# dump default values to a file you can edit
helm show values bitnami/nginx > my-values.yaml
```
