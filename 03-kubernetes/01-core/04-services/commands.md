# Services — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Need a backend Deployment first
kubectl apply -f ../03-deployments/deployment.yaml
kubectl rollout status deployment/hello-app
```

## Apply manifests

```bash
kubectl apply -f clusterip.yaml
kubectl apply -f nodeport.yaml
kubectl apply -f headless.yaml
```

## Inspect / verify

```bash
kubectl get svc
kubectl get svc hello-app -o wide
kubectl describe svc hello-app

# Endpoints (the actual pod IPs)
kubectl get endpoints hello-app
kubectl get endpointslices -l kubernetes.io/service-name=hello-app
```

## Common operations

```bash
# Hit a ClusterIP from inside the cluster
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://hello-app/

# DNS lookup of a Service
kubectl run tmp --rm -it --image=busybox --restart=Never -- \
  nslookup hello-app

# Headless: returns one A record per pod
kubectl run tmp --rm -it --image=busybox --restart=Never -- \
  nslookup hello-app-headless

# Port-forward a Service
kubectl port-forward svc/hello-app 8080:80

# NodePort access (kind / minikube)
kubectl get svc hello-app-np                    # note nodePort
minikube service hello-app-np --url             # minikube only
```

## Test the load balance

```bash
for i in $(seq 1 50); do
  kubectl run tmp-$i --rm --image=curlimages/curl --restart=Never -- \
    curl -s http://hello-app/ 2>/dev/null
done | sort | uniq -c
```

## Cleanup

```bash
kubectl delete -f clusterip.yaml -f nodeport.yaml -f headless.yaml
```

## One-liners worth memorising

```bash
kubectl get svc -A
kubectl get endpoints <svc>
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
kubectl describe svc <svc> | grep -E 'Selector|Endpoints|Type|IP|Port'
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- curl -s http://<svc>/
kubectl port-forward svc/<svc> 8080:80
```

## DNS reference

```
<service>.<namespace>.svc.cluster.local
hello-app.default.svc.cluster.local
hello-app                                # same namespace shortcut
```
