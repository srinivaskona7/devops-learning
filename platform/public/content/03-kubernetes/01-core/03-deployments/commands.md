# Deployments — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f deployment.yaml
```

## Inspect / verify

```bash
kubectl get deploy,rs,pod -l app=hello-app
kubectl rollout status deployment/hello-app
kubectl describe deployment hello-app
kubectl get deployment hello-app -o yaml | head -60
```

## Common operations

```bash
# Scale
kubectl scale deployment/hello-app --replicas=5

# Update image (creates a new ReplicaSet)
kubectl set image deployment/hello-app hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status deployment/hello-app

# Set env / args
kubectl set env deployment/hello-app FOO=bar
kubectl set resources deployment/hello-app -c hello --limits=cpu=200m,memory=256Mi

# History + rollback
kubectl rollout history deployment/hello-app
kubectl rollout history deployment/hello-app --revision=2
kubectl rollout undo deployment/hello-app
kubectl rollout undo deployment/hello-app --to-revision=1

# Pause / resume (stage multiple changes before rollout)
kubectl rollout pause deployment/hello-app
kubectl set env deployment/hello-app FOO=bar
kubectl set image deployment/hello-app hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout resume deployment/hello-app

# Restart all pods (re-pull config / rotate)
kubectl rollout restart deployment/hello-app
```

## Watch a rollout

```bash
kubectl rollout status deployment/hello-app --watch
kubectl get rs -l app=hello-app -w
kubectl get pods -l app=hello-app -w
```

## Cleanup

```bash
kubectl delete -f deployment.yaml
```

## One-liners worth memorising

```bash
kubectl rollout undo deployment/<name>
kubectl rollout restart deployment/<name>
kubectl scale deployment/<name> --replicas=N
kubectl set image deployment/<name> <container>=<image>:<tag>
kubectl get rs -l app=<name>                            # see all revisions
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[0].image}'
```
