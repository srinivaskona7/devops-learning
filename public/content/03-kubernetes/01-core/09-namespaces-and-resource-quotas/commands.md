# Namespaces & Resource Quotas — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f namespace.yaml
kubectl apply -f resourcequota.yaml
kubectl apply -f limitrange.yaml
```

## Inspect / verify

```bash
kubectl get ns
kubectl get ns demo --show-labels
kubectl describe ns demo
kubectl describe quota -n demo
kubectl describe limitrange -n demo

# What's namespaced vs cluster-scoped?
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
```

## Common operations

```bash
# Imperative create
kubectl create namespace demo
kubectl create namespace demo --dry-run=client -o yaml > namespace.yaml

# Set default ns for the current context
kubectl config set-context --current --namespace=demo

# Run a workload in a specific namespace
kubectl run test --image=nginx:1.27-alpine -n demo
kubectl get pod test -n demo -o jsonpath='{.spec.containers[0].resources}'
```

## Try the quota

```bash
# Saturate the pod-quota and watch it reject the 11th
for i in $(seq 1 12); do
  kubectl run test-$i --image=nginx:1.27-alpine -n demo
done
# 11th: "exceeded quota: pod-quota, requested: pods=1, used: pods=10, limited: pods=10"

kubectl get quota -n demo
kubectl get quota -n demo -o yaml
```

## Cleanup

```bash
kubectl delete namespace demo                # ← deletes EVERYTHING in the ns
```

## Stuck `Terminating` namespace

```bash
kubectl get namespace demo -o yaml           # look at finalizers
kubectl get namespace demo -o json \
  | jq '.spec.finalizers=[]' \
  | kubectl replace --raw "/api/v1/namespaces/demo/finalize" -f -
```

## One-liners worth memorising

```bash
kubectl get ns
kubectl config set-context --current --namespace=<ns>
kubectl describe quota -n <ns>
kubectl describe limitrange -n <ns>
kubectl api-resources --namespaced=true
kubectl get all -n <ns>
kubectl delete namespace <ns>
```
