# Service Mesh — Commands

> Quick pickup reference. Pair with `README.md` for theory. Istio-focused, with Linkerd / Cilium notes.

## Setup — Istio

```bash
# Install istioctl
brew install istioctl
# or:
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-*/bin:$PATH

# Install Istio
istioctl install --set profile=demo -y
kubectl -n istio-system get pods

# Enable sidecar injection on a namespace
kubectl label namespace default istio-injection=enabled --overwrite
```

## Setup — Linkerd

```bash
curl -fsL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
linkerd check --pre
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check
linkerd viz install | kubectl apply -f -
linkerd viz dashboard
```

## Setup — Cilium

```bash
cilium install
cilium status
cilium hubble enable
cilium hubble ui
```

## Apply manifests

```bash
kubectl apply -f istio-virtualservice.yaml
```

## Inspect / verify — Istio

```bash
istioctl analyze
istioctl proxy-status
istioctl proxy-config listeners <pod>.<ns>
istioctl proxy-config routes    <pod>.<ns>
istioctl proxy-config clusters  <pod>.<ns>
istioctl proxy-config endpoints <pod>.<ns>

kubectl get virtualservice,destinationrule,gateway -A
kubectl logs <pod> -c istio-proxy --tail=50
```

## Inspect / verify — Linkerd

```bash
linkerd check
linkerd viz stat deploy -n <ns>
linkerd viz top deploy/<name>
linkerd viz tap deploy/<name>
linkerd viz routes deploy/<name>
```

## Common operations

```bash
# Restart pods to inject sidecars after labeling
kubectl rollout restart deployment -n <ns>

# Verify sidecar exists
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].name}'

# mTLS check
istioctl x describe pod <pod>
linkerd viz edges deploy
```

## Cleanup

```bash
# Istio
istioctl uninstall --purge -y
kubectl delete namespace istio-system

# Linkerd
linkerd viz uninstall | kubectl delete -f -
linkerd uninstall   | kubectl delete -f -

# Cilium
cilium uninstall
```

## One-liners worth memorising

```bash
istioctl analyze
istioctl proxy-status
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
linkerd check
linkerd viz stat deploy -n <ns>
kubectl label namespace <ns> istio-injection=enabled --overwrite
kubectl rollout restart deployment -n <ns>
```
