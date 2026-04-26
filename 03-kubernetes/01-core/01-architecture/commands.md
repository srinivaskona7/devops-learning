# Architecture — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Assumes a running cluster (see ../00-cluster-setup)
kubectl cluster-info
```

## Apply manifests

This folder is read-only theory; no manifests to apply. Use the commands below to inspect a live cluster.

## Inspect / verify

```bash
# Control-plane components (kind / kubeadm style cluster)
kubectl get pods -n kube-system
kubectl get pods -n kube-system -l component=kube-apiserver
kubectl get pods -n kube-system -l component=etcd
kubectl get pods -n kube-system -l component=kube-scheduler
kubectl get pods -n kube-system -l component=kube-controller-manager

# Node components
kubectl get nodes -o wide
kubectl describe node kind-worker | head -40
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# What APIs the apiserver exposes
kubectl api-resources --verbs=list -o name | head -20
kubectl api-versions
```

## Common operations

```bash
# Component logs
kubectl logs -n kube-system -l component=kube-apiserver --tail=50
kubectl logs -n kube-system -l component=etcd --tail=50
kubectl logs -n kube-system -l component=kube-scheduler --tail=50
kubectl logs -n kube-system -l component=kube-controller-manager --tail=50

# Raw API reads
kubectl get --raw /api/v1/namespaces | head
kubectl get --raw /healthz
kubectl get --raw /readyz?verbose
kubectl get --raw /livez?verbose
kubectl get --raw /metrics | head
```

## Trace a pod creation

```bash
# Watch the chain in one terminal
kubectl get events --watch --sort-by=.lastTimestamp

# In another, create a pod and follow its phase
kubectl run trace --image=nginx:1.27-alpine
kubectl get pod trace -w
kubectl describe pod trace | grep -A5 Events
```

## Cleanup

```bash
kubectl delete pod trace --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get componentstatuses                # legacy, may be deprecated
kubectl get --raw /healthz
kubectl api-resources --namespaced=false
kubectl get pods -n kube-system -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -20
kubectl logs -n kube-system kube-apiserver-kind-control-plane | tail
```
