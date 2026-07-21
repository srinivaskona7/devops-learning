# Stateful Workloads — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl get storageclass
```

## Apply manifests

```bash
kubectl apply -f strimzi-kafka.yaml
```

## Inspect / verify — StatefulSet

```bash
kubectl get statefulset
kubectl get pods -l app=<name> -o wide          # ordered: pod-0, pod-1, ...
kubectl get pvc -l app=<name>
kubectl get endpoints <headless-svc>            # one A record per pod
```

## Stable DNS lookup

```bash
kubectl run tmp --rm -it --image=busybox --restart=Never -- \
  nslookup pod-0.<headless-svc>.<ns>.svc.cluster.local

kubectl run tmp --rm -it --image=busybox --restart=Never -- \
  nslookup <headless-svc>.<ns>.svc.cluster.local
```

## Common operations — StatefulSet

```bash
kubectl scale statefulset <name> --replicas=5
kubectl rollout status statefulset/<name>
kubectl rollout restart statefulset/<name>
kubectl rollout undo statefulset/<name>

# Phased rollout via partition (only pods with index >= partition update)
kubectl patch statefulset <name> -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

# Switch to parallel (skip ordering)
kubectl patch statefulset <name> -p '{"spec":{"podManagementPolicy":"Parallel"}}'
```

## PVC lifecycle

```bash
# Resize (StorageClass must allowVolumeExpansion)
kubectl edit pvc data-<name>-0
kubectl get pvc -l app=<name>

# StatefulSet does NOT auto-delete PVCs — clean manually
kubectl delete statefulset <name>
kubectl delete pvc -l app=<name>
```

## Strimzi Kafka

```bash
helm repo add strimzi https://strimzi.io/charts/
helm install strimzi strimzi/strimzi-kafka-operator -n kafka --create-namespace
kubectl get kafka,kafkatopic,kafkauser -n kafka
kubectl get pods -n kafka -w
```

## CloudNativePG (Postgres operator)

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml
kubectl get cluster.postgresql.cnpg.io
kubectl get pods -l cnpg.io/cluster=<name>
```

## Backup / restore (operator-specific)

```bash
# CloudNativePG
kubectl get backup,scheduledbackup -A
kubectl cnpg status <cluster>

# Strimzi
kubectl exec -it <kafka-pod> -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Cleanup

```bash
kubectl delete -f strimzi-kafka.yaml --ignore-not-found
kubectl delete pvc -l app=<name>
```

## One-liners worth memorising

```bash
kubectl get sts -A
kubectl scale sts <name> --replicas=N
kubectl rollout restart sts/<name>
kubectl get pvc -l app=<name>
kubectl delete pvc -l app=<name>
kubectl get pods -l app=<name> -o wide
nslookup pod-0.<headless-svc>.<ns>.svc.cluster.local
```
