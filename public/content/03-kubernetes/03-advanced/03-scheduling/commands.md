# Scheduling — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl get nodes --show-labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

## Apply manifests

```bash
kubectl apply -f affinity.yaml
kubectl apply -f tolerations.yaml
kubectl apply -f topology-spread.yaml
```

## Inspect / verify

```bash
kubectl get pods -o wide
kubectl describe pod <name> | grep -E 'Node:|Affinity|Tolerations|Topology'
kubectl get pods -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
```

## Label / taint nodes

```bash
# Label
kubectl label node kind-worker disktype=ssd
kubectl label node kind-worker tier=gpu --overwrite
kubectl label node kind-worker disktype-                 # remove

# Taint
kubectl taint nodes kind-worker dedicated=gpu:NoSchedule
kubectl taint nodes kind-worker dedicated=gpu:NoSchedule-  # remove

# Cordon / drain
kubectl cordon kind-worker
kubectl drain kind-worker --ignore-daemonsets --delete-emptydir-data
kubectl uncordon kind-worker
```

## Topology spread inspection

```bash
kubectl get pods -l app=<name> \
  -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\.kubernetes\.io/zone
```

## Priority + preemption

```bash
kubectl get priorityclass
kubectl describe priorityclass system-cluster-critical

cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: high }
value: 1000000
globalDefault: false
EOF
```

## Descheduler (one-shot Job)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/descheduler/master/kubernetes/job/job.yaml
kubectl logs -l app=descheduler -n kube-system
```

## Debug "Pending" pods

```bash
kubectl describe pod <name> | tail -20            # Events: FailedScheduling
kubectl get events --sort-by=.lastTimestamp | grep FailedScheduling
kubectl get pod <name> -o jsonpath='{.status.conditions}'
```

## Cleanup

```bash
kubectl delete -f affinity.yaml -f tolerations.yaml -f topology-spread.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get nodes --show-labels
kubectl label node <node> <k>=<v>
kubectl taint node <node> <k>=<v>:NoSchedule
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl get priorityclass
kubectl describe pod <name> | tail -20
```
