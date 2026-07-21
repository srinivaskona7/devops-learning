# ConfigMaps & Secrets — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f pod-with-config.yaml
```

## Inspect / verify

```bash
kubectl get cm,secret
kubectl describe cm app-config
kubectl describe secret db-credentials
kubectl describe pod app-with-config

# Verify the config landed in the container
kubectl exec app-with-config -- env | grep -E 'APP_|DB_'
kubectl exec app-with-config -- cat /etc/config/app.properties
kubectl exec app-with-config -- cat /etc/secrets/db-password
```

## Decode a secret

```bash
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d ; echo
kubectl get secret db-credentials -o yaml
```

## Create from CLI (imperative)

```bash
# ConfigMap
kubectl create configmap app-config --from-literal=APP_ENV=prod
kubectl create configmap app-config --from-file=app.properties
kubectl create configmap app-config --from-file=./config-dir/

# Secret
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='S3cret!'

# Image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=USER \
  --docker-password=TOKEN \
  --docker-email=you@example.com

# TLS secret
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key
```

## Common operations

```bash
# Edit (re-applies; pods using volume mounts pick up after kubelet sync)
kubectl edit configmap app-config

# Force-restart pods to pick up env-var changes
kubectl rollout restart deployment/<name>

# Mark immutable (prevents edits, improves perf)
kubectl patch configmap app-config -p '{"immutable":true}'
```

## Cleanup

```bash
kubectl delete -f configmap.yaml -f secret.yaml -f pod-with-config.yaml
```

## One-liners worth memorising

```bash
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d
kubectl create configmap <n> --from-literal=K=V --dry-run=client -o yaml
kubectl create secret generic <n> --from-literal=K=V --dry-run=client -o yaml
kubectl rollout restart deployment/<name>           # propagate env-var change
kubectl get cm,secret -A
```
