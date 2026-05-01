# Pods — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
kubectl config current-context
```

## Apply manifests

```bash
kubectl apply -f 01-hello-world.yaml
kubectl apply -f 02-multi-container.yaml
kubectl apply -f 03-init-container.yaml
```

## Inspect / verify

```bash
# Hello world
kubectl get pod hello-world -w
kubectl describe pod hello-world
kubectl logs hello-world

# Multi-container — name the container with -c
kubectl get pod multi-container
kubectl logs multi-container -c app
kubectl logs multi-container -c log-shipper
kubectl logs multi-container --all-containers=true

# Init container — watch phase transitions
kubectl get pod init-demo -w           # Init:0/1 → PodInitializing → Running
kubectl logs init-demo -c wait-for-it
kubectl logs init-demo -c app

# All pods
kubectl get pods -o wide
kubectl get pod hello-world -o yaml
```

## Common operations

```bash
# Port-forward (test a pod without a Service)
kubectl port-forward pod/hello-world 8080:8080
curl localhost:8080

# Exec into a container
kubectl exec -it hello-world -- sh
kubectl exec multi-container -c app -- env

# Previous container logs (after a crash)
kubectl logs hello-world --previous

# Force-restart a pod
kubectl delete pod hello-world

# Pod events
kubectl get events --field-selector involvedObject.name=hello-world
```

## Debug a stuck pod

```bash
kubectl describe pod <name> | tail -30          # events at the bottom
kubectl logs <name> --previous                  # last crash output
kubectl get events --sort-by=.lastTimestamp | tail -20
kubectl debug -it <name> --image=nicolaka/netshoot --target=<container>
```

## Cleanup

```bash
kubectl delete -f 01-hello-world.yaml -f 02-multi-container.yaml -f 03-init-container.yaml
```

## One-liners worth memorising

```bash
kubectl run tmp --rm -it --image=busybox --restart=Never -- sh
kubectl logs <pod> -c <container> --previous
kubectl exec -it <pod> -c <container> -- sh
kubectl get pod <pod> -o jsonpath='{.status.phase}'
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[*].ready}'
kubectl port-forward pod/<pod> 8080:8080
```
