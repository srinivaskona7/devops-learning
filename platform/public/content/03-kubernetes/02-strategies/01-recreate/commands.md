# Recreate Strategy — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello-recreate
```

## Inspect / verify

```bash
kubectl get deploy hello-recreate -o jsonpath='{.spec.strategy.type}'; echo   # Recreate
kubectl get pods -L version --watch
kubectl rollout history deployment/hello-recreate
```

## Run the demo

```bash
bash demo.sh
```

## Common operations — trigger Recreate

```bash
# Update image — old pods are killed BEFORE new ones start (downtime)
kubectl set image deployment/hello-recreate hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status deployment/hello-recreate

# Watch downtime window
kubectl get pods -L version -w
```

## Detect downtime with continuous curl

```bash
# In another terminal
while true; do
  curl -s --max-time 1 http://hello-recreate/ || echo "DOWN $(date +%T)"
  sleep 0.2
done
```

## Rollback

```bash
kubectl rollout undo deployment/hello-recreate
```

## Cleanup

```bash
kubectl delete -f deployment.yaml --ignore-not-found
kubectl delete svc hello-recreate --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get deploy <name> -o jsonpath='{.spec.strategy.type}'
kubectl set image deployment/<name> <container>=<image>:<tag>
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
kubectl get pods -L version -w
```
