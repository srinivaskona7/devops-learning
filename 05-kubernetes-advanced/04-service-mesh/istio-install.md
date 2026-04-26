# Install Istio (demo)

```bash
# 1. Download
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# 2. Install with the demo profile (do NOT use in production)
istioctl install --set profile=demo -y

# 3. Auto-injection in a namespace
kubectl label namespace default istio-injection=enabled

# 4. Verify
istioctl analyze
istioctl proxy-status

# 5. Try the bookinfo sample
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

## Ambient mode (Istio 1.22+ GA)
```bash
istioctl install --set profile=ambient -y
kubectl label ns default istio.io/dataplane-mode=ambient
# No sidecar injection. Apply a Waypoint for L7:
istioctl x waypoint apply --enroll-namespace
```
