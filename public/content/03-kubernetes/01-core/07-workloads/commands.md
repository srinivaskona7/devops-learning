# Workloads — Commands

> Quick pickup reference. Pair with `README.md` for theory. Covers StatefulSet, DaemonSet, Job, CronJob.

## Setup

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

## Apply manifests

```bash
kubectl apply -f statefulset.yaml
kubectl apply -f daemonset.yaml
kubectl apply -f job.yaml
kubectl apply -f cronjob.yaml
```

## Inspect / verify

```bash
# StatefulSet — ordered creation
kubectl get statefulset
kubectl get pods -l app=zk -w                # zk-0, zk-1, zk-2 in order
kubectl get pvc -l app=zk

# DaemonSet — one pod per node
kubectl get ds
kubectl get ds,pods -l app=node-agent -o wide

# Job — runs to completion
kubectl get jobs
kubectl get jobs,pods -l app=pi
kubectl logs -l app=pi

# CronJob
kubectl get cronjob
kubectl get jobs -l app=hello-cron
kubectl logs -l app=hello-cron --tail=10
```

## Common operations — StatefulSet

```bash
kubectl scale statefulset zk --replicas=5
kubectl rollout status statefulset/zk
kubectl rollout restart statefulset/zk
kubectl rollout undo statefulset/zk
kubectl exec -it zk-0 -- sh
```

## Common operations — DaemonSet

```bash
kubectl rollout status ds/node-agent
kubectl rollout restart ds/node-agent
kubectl rollout history ds/node-agent
# Run on tainted nodes? Add a toleration in the manifest.
```

## Common operations — Job

```bash
# Run-to-completion behavior
kubectl get job pi -o jsonpath='{.status.succeeded}'

# Suspend / resume (K8s 1.24+)
kubectl patch job pi -p '{"spec":{"suspend":true}}'
kubectl patch job pi -p '{"spec":{"suspend":false}}'

# Manual run from a CronJob
kubectl create job --from=cronjob/hello-cron manual-run-1
```

## Common operations — CronJob

```bash
kubectl get cronjob hello-cron -o jsonpath='{.spec.schedule}'
kubectl patch cronjob hello-cron -p '{"spec":{"suspend":true}}'    # pause
kubectl patch cronjob hello-cron -p '{"spec":{"suspend":false}}'   # resume
```

## Cleanup

```bash
kubectl delete -f statefulset.yaml -f daemonset.yaml -f job.yaml -f cronjob.yaml
kubectl delete pvc -l app=zk                 # StatefulSet PVCs are NOT auto-deleted
```

## One-liners worth memorising

```bash
kubectl get sts,ds,job,cronjob -A
kubectl rollout restart statefulset/<name>
kubectl create job --from=cronjob/<name> <run-name>
kubectl patch cronjob <name> -p '{"spec":{"suspend":true}}'
kubectl get pods -l app=<name> -o wide
kubectl delete pvc -l app=<name>
```
