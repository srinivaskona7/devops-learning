# Blue / Green — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f deployment-blue.yaml
kubectl apply -f deployment-green.yaml
kubectl apply -f service.yaml                          # selector starts on color: blue
kubectl rollout status deployment/hello-bg-blue
kubectl rollout status deployment/hello-bg-green
```

## Inspect / verify

```bash
# Which color is live?
kubectl get svc hello-bg -o jsonpath='{.spec.selector.color}'; echo

# Pods + colors
kubectl get pods -L color,version
kubectl get endpoints hello-bg
```

## Run the demo

```bash
bash demo.sh
```

## Smoke-test green BEFORE cutover

```bash
# Direct port-forward to a green pod
kubectl port-forward deploy/hello-bg-green 8081:8080
curl localhost:8081/

# Or expose a debug Service
kubectl expose deploy hello-bg-green --name hello-bg-green-debug --port=80 --target-port=8080
kubectl port-forward svc/hello-bg-green-debug 8081:80
```

## Atomic switch (blue → green)

```bash
kubectl patch svc hello-bg -p '{"spec":{"selector":{"color":"green"}}}'
kubectl get svc hello-bg -o jsonpath='{.spec.selector.color}'; echo

# Verify
curl http://<svc-or-ingress>/                   # version 2.0
```

## Instant rollback (green → blue)

```bash
kubectl patch svc hello-bg -p '{"spec":{"selector":{"color":"blue"}}}'
```

## Scale down old color after confidence window

```bash
kubectl scale deployment/hello-bg-blue --replicas=0
```

## Cleanup

```bash
kubectl delete -f deployment-blue.yaml -f deployment-green.yaml -f service.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl patch svc <svc> -p '{"spec":{"selector":{"color":"green"}}}'
kubectl get svc <svc> -o jsonpath='{.spec.selector.color}'
kubectl scale deploy/<old-color> --replicas=0
kubectl get pods -L color,version
kubectl get endpoints <svc>
```
