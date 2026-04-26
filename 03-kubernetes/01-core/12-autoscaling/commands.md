# Autoscaling — Commands

> Quick pickup reference. Pair with `README.md` for theory. Covers HPA + metrics-server.

## Setup — install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind only: skip TLS verify against kubelet
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes                              # verify metrics flowing
kubectl top pods -A
```

## Apply manifests

```bash
# Need a backend with resources.requests.cpu set
kubectl apply -f ../03-deployments/deployment.yaml
kubectl apply -f ../04-services/clusterip.yaml
kubectl apply -f hpa.yaml
```

## Inspect / verify

```bash
kubectl get hpa
kubectl get hpa -w
kubectl describe hpa hello-app
kubectl get hpa hello-app -o yaml
```

## Generate load

```bash
kubectl run -it --rm load --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://hello-app/; done"

# Watch replicas climb
kubectl get hpa,deploy hello-app -w
kubectl top pods -l app=hello-app
```

## Imperative HPA

```bash
kubectl autoscale deployment hello-app --cpu-percent=50 --min=2 --max=10
```

## VPA (if installed)

```bash
kubectl get vpa
kubectl describe vpa <name>
kubectl get vpa <name> -o jsonpath='{.status.recommendation}'
```

## KEDA (if installed)

```bash
kubectl get scaledobject,scaledjob -A
kubectl describe scaledobject <name>
kubectl get hpa                                # KEDA creates an HPA under the hood
```

## Cluster Autoscaler (cloud)

```bash
# Cloud-specific — confirm it's running
kubectl -n kube-system get deploy cluster-autoscaler
kubectl -n kube-system logs deploy/cluster-autoscaler --tail=100
```

## Cleanup

```bash
kubectl delete -f hpa.yaml
```

## One-liners worth memorising

```bash
kubectl top nodes
kubectl top pods -A
kubectl get hpa -A
kubectl autoscale deployment <name> --cpu-percent=50 --min=2 --max=10
kubectl describe hpa <name> | tail -20
kubectl get hpa <name> -o jsonpath='{.status.currentReplicas}/{.status.desiredReplicas}'
```
