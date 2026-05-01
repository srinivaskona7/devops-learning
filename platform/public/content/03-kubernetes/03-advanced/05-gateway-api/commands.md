# Gateway API — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup — install Gateway API CRDs + a controller

```bash
# CRDs (standard channel)
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# Pick ONE controller. Example: Envoy Gateway
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.1.0 -n envoy-gateway-system --create-namespace
kubectl -n envoy-gateway-system get pods

# Or: NGINX Gateway Fabric / Istio / kgateway / Cilium / Contour
```

## Apply manifests

```bash
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

## Inspect / verify

```bash
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute,grpcroute,tcproute,udproute,tlsroute -A
kubectl describe gateway <name>
kubectl describe httproute <name>

# Gateway status / accepted listeners
kubectl get gateway <name> -o jsonpath='{.status}' | jq
```

## Test routing

```bash
# Find Gateway address
GW=$(kubectl get gateway <name> -o jsonpath='{.status.addresses[0].value}')
curl -H "Host: app.example.com" http://$GW/
```

## Common operations

```bash
# Cross-namespace ReferenceGrant
kubectl get referencegrant -A

# Watch Gateway status
kubectl get gateway <name> -w

# Switch GatewayClass
kubectl patch gateway <name> --type=merge -p '{"spec":{"gatewayClassName":"<class>"}}'
```

## GAMMA (mesh) usage

```bash
# Same HTTPRoute attached to a Service to control east-west
kubectl get httproute -A
kubectl describe httproute <name>
```

## Cleanup

```bash
kubectl delete -f httproute.yaml -f gateway.yaml --ignore-not-found
kubectl delete -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

## One-liners worth memorising

```bash
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl describe gateway <name>
kubectl describe httproute <name>
kubectl get gateway <name> -o jsonpath='{.status.addresses}'
```
