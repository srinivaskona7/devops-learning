# A/B Testing (header-based) — Commands

> Quick pickup reference. Pair with `README.md` for theory. Uses Istio.

## Setup — install Istio

```bash
# Install Istio (one-time)
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled --overwrite
kubectl get pods -n istio-system
```

## Backend Services (split stable + canary into two Services)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: hello-v1 }
spec:
  selector: { app: hello-canary-app, track: stable }
  ports: [{ port: 80, targetPort: 8080 }]
---
apiVersion: v1
kind: Service
metadata: { name: hello-v2 }
spec:
  selector: { app: hello-canary-app, track: canary }
  ports: [{ port: 80, targetPort: 8080 }]
EOF
```

## Apply manifests

```bash
kubectl apply -f virtualservice.yaml
```

## Inspect / verify

```bash
kubectl get virtualservice
kubectl get virtualservice hello-ab -o yaml
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
istioctl analyze
```

## Test header routing

```bash
GW=$(kubectl -n istio-system get svc istio-ingressgateway \
       -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Without header → v1
curl -s http://$GW/

# With header → v2
curl -s -H "x-user: beta" http://$GW/
```

## Run multiple probes

```bash
for i in $(seq 1 20); do curl -s http://$GW/ ; done | sort | uniq -c
for i in $(seq 1 20); do curl -s -H "x-user: beta" http://$GW/ ; done | sort | uniq -c
```

## Common operations

```bash
# Inspect Istio sidecars on a pod
istioctl proxy-status
istioctl proxy-config listeners <pod>.<ns>
istioctl proxy-config routes <pod>.<ns>
istioctl proxy-config clusters <pod>.<ns>

# Tail an Envoy access log
kubectl logs -l app=hello-canary-app -c istio-proxy --tail=50
```

## Cleanup

```bash
kubectl delete -f virtualservice.yaml --ignore-not-found
kubectl delete svc hello-v1 hello-v2 --ignore-not-found
```

## One-liners worth memorising

```bash
istioctl install --set profile=demo -y
kubectl label namespace <ns> istio-injection=enabled --overwrite
istioctl analyze
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
curl -H "x-user: beta" http://$GW/
```
