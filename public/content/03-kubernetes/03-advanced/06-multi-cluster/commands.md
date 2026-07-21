# Multi-Cluster — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup — Cluster API (CAPI) for kind

```bash
# clusterctl
brew install clusterctl

# Init management cluster
clusterctl init --infrastructure docker
kubectl get pods -A | grep -E 'capi|cap'

# Generate a workload cluster manifest
clusterctl generate cluster capi-quickstart \
  --flavor development --kubernetes-version v1.30.0 \
  --control-plane-machine-count=1 --worker-machine-count=2 \
  > capi-quickstart.yaml

kubectl apply -f capi-quickstart.yaml
clusterctl describe cluster capi-quickstart
```

## Get kubeconfig of a CAPI workload cluster

```bash
clusterctl get kubeconfig capi-quickstart > capi.kubeconfig
KUBECONFIG=capi.kubeconfig kubectl get nodes
```

## Apply manifests

```bash
kubectl apply -f clusterapi-example.yaml
```

## Inspect / verify

```bash
kubectl get clusters -A
kubectl get machines -A
kubectl get machinedeployments -A
kubectl get kubeadmcontrolplane -A
kubectl describe cluster <name>
```

## Karmada

```bash
# Install Karmada
kubectl krew install karmada
karmadactl init

# Register a member cluster
karmadactl join member1 --cluster-kubeconfig=member1.kubeconfig

# List members
kubectl get clusters --kubeconfig=karmada.config
karmadactl get cluster
```

## Argo CD ApplicationSet (GitOps fan-out)

```bash
kubectl apply -n argocd -f appset.yaml
kubectl -n argocd get applicationset
kubectl -n argocd get applications
argocd appset list
argocd appset get <name>
```

## Multi-cluster context juggling

```bash
# Merge kubeconfigs
KUBECONFIG=cluster1.yaml:cluster2.yaml kubectl config view --flatten > merged.yaml
export KUBECONFIG=merged.yaml
kubectl config get-contexts
kubectl config use-context cluster1

# kubectx / kubens
brew install kubectx
kubectx
kubens
```

## Mesh federation

```bash
# Istio multi-primary
istioctl create-remote-secret --context=cluster1 --name=cluster1 \
  | kubectl --context=cluster2 apply -f -

# Cilium ClusterMesh
cilium clustermesh enable --context cluster1
cilium clustermesh connect --context cluster1 --destination-context cluster2
cilium clustermesh status
```

## Cleanup

```bash
kubectl delete -f capi-quickstart.yaml --ignore-not-found
clusterctl delete --all
```

## One-liners worth memorising

```bash
clusterctl get kubeconfig <cluster> > <cluster>.kubeconfig
kubectl config get-contexts
kubectl config use-context <ctx>
kubectx
karmadactl join <name> --cluster-kubeconfig=<file>
argocd appset list
```
