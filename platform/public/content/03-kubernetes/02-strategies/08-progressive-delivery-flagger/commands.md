# Progressive Delivery with Flagger — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup — install Flagger (NGINX example)

```bash
helm repo add flagger https://flagger.app
helm repo update

kubectl apply -k github.com/fluxcd/flagger//kustomize/crd

helm upgrade -i flagger flagger/flagger \
  --namespace ingress-nginx \
  --set meshProvider=nginx \
  --set metricsServer=http://prometheus.monitoring:9090

kubectl -n ingress-nginx get pods -l app.kubernetes.io/name=flagger
```

## Apply manifests

```bash
# Need a normal Deployment + Service + Ingress already in place
kubectl apply -f canary.yaml
```

## Inspect / verify

```bash
kubectl get canary
kubectl describe canary hello | tail -50
kubectl get canary hello -o jsonpath='{.status.phase}'; echo
# Phase: Initialized | Progressing | Promoting | Succeeded | Failed
```

## Trigger a release (Flagger watches the Deployment)

```bash
kubectl set image deployment/hello hello=gcr.io/google-samples/hello-app:2.0

# Watch progression
kubectl get events --watch --field-selector involvedObject.kind=Canary
kubectl describe canary hello | tail -30
```

## Common operations

```bash
# Trigger an out-of-band rollout
kubectl annotate canary hello flagger.app/rollout="$(date +%s)" --overwrite

# Inspect primary + canary objects (managed by Flagger)
kubectl get deploy,svc -l app=hello
kubectl get deploy hello-primary
kubectl get deploy hello                          # this is the canary target

# Flagger logs
kubectl -n ingress-nginx logs deploy/flagger --tail=100
kubectl -n ingress-nginx logs deploy/flagger -f
```

## Manual rollback

```bash
# Roll the underlying Deployment back; Flagger will re-converge
kubectl rollout undo deployment/hello
```

## Cleanup

```bash
kubectl delete -f canary.yaml --ignore-not-found
helm -n ingress-nginx uninstall flagger
```

## One-liners worth memorising

```bash
kubectl get canary -A
kubectl describe canary <name>
kubectl get canary <name> -o jsonpath='{.status.phase}'
kubectl -n ingress-nginx logs deploy/flagger --tail=100
kubectl annotate canary <name> flagger.app/rollout="$(date +%s)" --overwrite
```
