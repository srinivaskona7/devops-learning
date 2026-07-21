# Kubernetes Changelog — Commands

> Quick pickup reference. Pair with `README.md` for theory. Practical commands for tracking, upgrading, and inspecting versions.

## Setup

```bash
kubectl version
kubectl version --output=json | jq
```

## Inspect cluster + node versions

```bash
kubectl get nodes -o wide
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'

# Control plane components
kubectl -n kube-system get pods -l tier=control-plane \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

## Feature gates

```bash
# Enabled feature gates on apiserver
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml \
  | grep -E 'feature-gates'

# kubelet feature gates (per node)
kubectl get --raw "/api/v1/nodes/<node>/proxy/configz" | jq '.kubeletconfig.featureGates'
```

## Browse releases

```bash
# Release blog (open in browser)
open https://kubernetes.io/blog/

# CHANGELOG (raw)
curl -sL https://raw.githubusercontent.com/kubernetes/kubernetes/master/CHANGELOG/CHANGELOG-1.30.md | less
curl -sL https://raw.githubusercontent.com/kubernetes/kubernetes/master/CHANGELOG/CHANGELOG-1.33.md | less

# KEPs
open https://github.com/kubernetes/enhancements
```

## Deprecations & removed APIs (audit before upgrade)

```bash
# Run kubent (kube-no-trouble)
kubent
kubent --target-version 1.30

# pluto
pluto detect-helm -o wide
pluto detect-files -d ./manifests
```

## Upgrade — kubeadm cluster

```bash
sudo apt-get update && sudo apt-get install -y kubeadm=1.30.x-*
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.30.0

# Drain + upgrade kubelet on each node
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
sudo apt-get install -y kubelet=1.30.x-* kubectl=1.30.x-*
sudo systemctl restart kubelet
kubectl uncordon <node>
```

## Upgrade — kind

```bash
kind delete cluster --name <name>
kind create cluster --name <name> --image kindest/node:v1.30.0
```

## Upgrade — managed (cloud)

```bash
# EKS
aws eks update-cluster-version --name <c> --kubernetes-version 1.30
aws eks update-nodegroup-version --cluster-name <c> --nodegroup-name <ng>

# GKE
gcloud container clusters upgrade <c> --master --cluster-version=1.30
gcloud container clusters upgrade <c> --node-pool=<np> --cluster-version=1.30

# AKS
az aks upgrade -g <rg> -n <c> --kubernetes-version 1.30
```

## One-liners worth memorising

```bash
kubectl version --output=json | jq
kubectl get nodes -o wide
kubent --target-version 1.30
pluto detect-files -d ./manifests
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
sudo kubeadm upgrade plan
```
