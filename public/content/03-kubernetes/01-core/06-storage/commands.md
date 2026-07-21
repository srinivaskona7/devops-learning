# Storage — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl get storageclass                     # kind ships 'standard'
```

## Apply manifests

```bash
kubectl apply -f pvc.yaml
kubectl apply -f statefulset-with-pvc.yaml
```

## Inspect / verify

```bash
# PVC + bound PV
kubectl get pvc data-pvc                     # STATUS should be Bound
kubectl get pv
kubectl describe pvc data-pvc
kubectl describe pv <pv-name>

# StatefulSet pods + per-pod PVCs
kubectl get pods -l app=cache -o wide
kubectl get pvc -l app=cache                 # data-cache-0, data-cache-1, ...
```

## Common operations

```bash
# Write data, kill the pod, verify persistence
kubectl exec cache-0 -- sh -c 'echo "persisted!" > /data/test.txt'
kubectl delete pod cache-0
kubectl get pod cache-0 -w                   # recreated by StatefulSet
kubectl exec cache-0 -- cat /data/test.txt   # still there

# Resize a PVC (StorageClass must allowVolumeExpansion)
kubectl edit pvc data-pvc                    # bump spec.resources.requests.storage
kubectl get pvc data-pvc -w

# Inspect StorageClasses + provisioner
kubectl get sc
kubectl describe sc standard
kubectl get sc -o yaml | grep -E 'name:|provisioner:|reclaimPolicy:'
```

## Static PV (rare, when not using a provisioner)

```bash
kubectl get pv
kubectl describe pv <name>
kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

## Cleanup

```bash
kubectl delete -f statefulset-with-pvc.yaml
kubectl delete pvc -l app=cache              # StatefulSet does NOT auto-delete PVCs
kubectl delete -f pvc.yaml
kubectl get pv                               # confirm reclaim
```

## One-liners worth memorising

```bash
kubectl get pvc,pv
kubectl get sc
kubectl describe pvc <name>
kubectl get pvc <name> -o jsonpath='{.status.phase}'
kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
kubectl delete pvc -l app=<name>
```
