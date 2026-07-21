# RBAC — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f rbac-example.yaml
```

## Inspect / verify

```bash
kubectl get sa,role,rolebinding,clusterrole,clusterrolebinding
kubectl describe role <name>
kubectl describe rolebinding <name>
kubectl get sa app-reader -o yaml
```

## Permission checks

```bash
# As yourself
kubectl auth can-i list configmaps
kubectl auth can-i delete pods -n kube-system

# As a ServiceAccount
kubectl auth can-i list configmaps --as=system:serviceaccount:default:app-reader
kubectl auth can-i delete pods --as=system:serviceaccount:default:app-reader

# Full audit of what an SA can do
kubectl auth can-i --list --as=system:serviceaccount:default:app-reader
```

## Run a pod AS that ServiceAccount

```bash
kubectl run test --rm -it --image=bitnami/kubectl --restart=Never \
  --overrides='{"spec":{"serviceAccountName":"app-reader"}}' -- \
  kubectl get configmaps
```

## Common operations

```bash
# Imperative create
kubectl create serviceaccount app-reader
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create rolebinding bind-pod-reader --role=pod-reader --serviceaccount=default:app-reader
kubectl create clusterrolebinding admin-binding --clusterrole=cluster-admin --user=alice@example.com

# Token for an SA (short-lived, K8s 1.24+)
kubectl create token app-reader --duration=1h

# Disable token automount on a pod / SA
kubectl patch sa app-reader -p '{"automountServiceAccountToken":false}'
```

## Inspect built-in roles

```bash
kubectl get clusterrole | grep -E 'cluster-admin|admin|edit|view'
kubectl describe clusterrole view
kubectl describe clusterrole edit
```

## Cleanup

```bash
kubectl delete -f rbac-example.yaml
```

## One-liners worth memorising

```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>
kubectl create token <sa> --duration=1h
kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa>
kubectl get rolebinding,clusterrolebinding -A -o wide
```
