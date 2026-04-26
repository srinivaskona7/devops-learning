# Shadow / Mirror Traffic — Commands

> Quick pickup reference. Pair with `README.md` for theory. Uses Istio mirror.

## Setup

```bash
# Istio installed + sidecar injection enabled
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled --overwrite

# Reuse hello-v1 + hello-v2 Services from 06-ab-testing
```

## Apply manifests

```bash
kubectl apply -f virtualservice-mirror.yaml
```

## Inspect / verify

```bash
kubectl get virtualservice hello-mirror -o yaml
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
```

## Drive primary load + verify mirror sees it

```bash
# Drive load to v1
for i in $(seq 1 200); do curl -s http://hello-v1/ >/dev/null; done

# Mirror logs (v2 sees the same requests)
kubectl logs -l app=hello-canary-app,track=canary --tail=50
kubectl logs -l app=hello-canary-app,track=canary -c istio-proxy --tail=50
```

## Tune mirror percentage

```bash
# Edit VirtualService to change mirrorPercentage.value
kubectl edit virtualservice hello-mirror

# Or patch
kubectl patch virtualservice hello-mirror --type=merge -p '
spec:
  http:
    - route:
        - destination: { host: hello-v1 }
      mirror: { host: hello-v2 }
      mirrorPercentage: { value: 50.0 }
'
```

## Verify v2 metrics

```bash
kubectl exec -it deploy/<v2-pod> -- wget -qO- localhost:8080/metrics | head -30
```

## Cleanup

```bash
kubectl delete -f virtualservice-mirror.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get virtualservice
kubectl edit virtualservice <name>
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
kubectl logs -l <selector> -c istio-proxy --tail=50
istioctl proxy-status
```
