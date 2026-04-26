# Cluster Setup — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# kubectl
brew install kubectl                         # macOS
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# kind (recommended)
brew install kind                            # macOS
[ "$(uname -m)" = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
```

## Apply manifests

```bash
# Create cluster from this folder's config
kind create cluster --config kind-cluster.yaml

# Pin image on Apple Silicon
kind create cluster --config kind-cluster.yaml --image kindest/node:v1.30.0
```

## Inspect / verify

```bash
./verify.sh
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl config current-context
kubectl config get-contexts
```

Expected node listing:

```
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   45s   v1.30.x
kind-worker          Ready    <none>          30s   v1.30.x
kind-worker2         Ready    <none>          30s   v1.30.x
```

## Common operations

```bash
# Switch / use context
kubectl config use-context kind-kind

# Load a local docker image into kind nodes (no registry push)
kind load docker-image my-app:dev --name devops-learning

# Recreate cluster fast
kind delete cluster --name devops-learning
kind create cluster --config kind-cluster.yaml
```

## Alternatives

```bash
# minikube
minikube start --nodes 3 --cpus 2 --memory 4g --kubernetes-version=v1.30.0
minikube service <svc> --url

# k3d
k3d cluster create devops --servers 1 --agents 2 -p "80:80@loadbalancer"
k3d cluster delete devops

# Docker Desktop: Settings → Kubernetes → Enable
```

## Cleanup

```bash
kind delete cluster --name devops-learning
minikube delete
k3d cluster delete devops
docker system prune                          # reclaim disk if pods stay Pending
```

## One-liners worth memorising

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info dump | head -50
kubectl config current-context
kind get clusters
docker ps --filter label=io.x-k8s.kind.cluster
```
