# Ingress — Commands

> Quick pickup reference. Pair with `README.md` for theory. Uses ingress-nginx.

## Setup

```bash
# Install ingress-nginx (kind-specific manifest exposes :80/:443 via extraPortMappings)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

# Backend Deployment + Service
kubectl apply -f ../03-deployments/deployment.yaml
kubectl apply -f ../04-services/clusterip.yaml
```

## Apply manifests

```bash
kubectl apply -f ingress.yaml
```

## Inspect / verify

```bash
kubectl get ingress
kubectl get ingress -A
kubectl describe ingress hello
kubectl get ingressclass
```

## Test

```bash
# kind maps localhost:80 -> ingress controller via extraPortMappings
curl -H "Host: hello.local" http://localhost/
curl -kv -H "Host: hello.local" https://localhost/

# Or use port-forward
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
curl -H "Host: hello.local" http://localhost:8080/
```

## Common operations

```bash
# Controller logs
kubectl -n ingress-nginx logs -l app.kubernetes.io/component=controller --tail=100

# Annotations cheat-sheet (ingress-nginx)
kubectl annotate ingress hello \
  nginx.ingress.kubernetes.io/rewrite-target=/ \
  nginx.ingress.kubernetes.io/ssl-redirect=true

# TLS Secret
kubectl create secret tls hello-tls --cert=tls.crt --key=tls.key
```

## cert-manager (auto Let's Encrypt)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl get pods -n cert-manager
kubectl get clusterissuer,issuer -A
kubectl get certificate -A
```

## Cleanup

```bash
kubectl delete -f ingress.yaml
# (Optional) uninstall the controller
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## One-liners worth memorising

```bash
kubectl get ingress -A
kubectl describe ingress <name>
kubectl get ingressclass
kubectl -n ingress-nginx logs -l app.kubernetes.io/component=controller --tail=50
curl -H "Host: <host>" http://localhost/
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
```
