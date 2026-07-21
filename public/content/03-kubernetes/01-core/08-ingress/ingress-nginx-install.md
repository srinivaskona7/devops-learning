# Installing ingress-nginx

## On kind (recommended for this folder)

The kind cluster from `00-cluster-setup/kind-cluster.yaml` already has the right port mappings + node labels.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

kubectl get pods -n ingress-nginx
kubectl get svc  -n ingress-nginx
```

## On any cloud (Helm — preferred for prod)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.metrics.enabled=true \
  --set controller.podAnnotations."prometheus\.io/scrape"=true \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=128Mi
```

## On minikube

```bash
minikube addons enable ingress
```

## Verify

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass            # 'nginx' should be present
```

## Uninstall

```bash
helm uninstall ingress-nginx -n ingress-nginx
# or for kind:
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Reference

- [ingress-nginx install docs](https://kubernetes.github.io/ingress-nginx/deploy/)
