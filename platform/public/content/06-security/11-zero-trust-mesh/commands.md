# Zero Trust Service Mesh — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PATH:$PWD/bin
istioctl install --set profile=default -y
kubectl label namespace app istio-injection=enabled

# Linkerd
curl -fsL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
linkerd check --pre
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
kubectl annotate namespace app linkerd.io/inject=enabled

# SPIRE (standalone SPIFFE)
helm repo add spiffe https://spiffe.github.io/helm-charts-hardened
helm install spire spiffe/spire -n spire --create-namespace
```

## Apply policies / manifests

```bash
# Istio — mesh-wide STRICT mTLS
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: { name: default, namespace: istio-system }
spec:
  mtls: { mode: STRICT }
EOF

# AuthorizationPolicy — default deny in a namespace
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: { name: default-deny, namespace: app }
spec: {}
EOF

# Allow specific service-to-service edge
kubectl apply -f istio-authz-policy.yaml

# Linkerd — Server + ServerAuthorization (replaces NetworkPolicy at L7)
kubectl apply -f - <<'EOF'
apiVersion: policy.linkerd.io/v1beta1
kind: Server
metadata: { name: api, namespace: app }
spec:
  podSelector: { matchLabels: { app: api } }
  port: http
EOF
```

## Inspect / verify

```bash
# Istio — proxy + mTLS status
istioctl proxy-status
istioctl proxy-config cluster <pod>.<ns>
istioctl authn tls-check <pod>.<ns>.svc.cluster.local
istioctl analyze -n app

# Confirm sidecar injected
kubectl get pod <name> -n app -o jsonpath='{.spec.containers[*].name}'

# Linkerd
linkerd check
linkerd viz install | kubectl apply -f -
linkerd viz dashboard
linkerd viz authz -n app deploy/api
linkerd viz edges -n app

# Verify mTLS is actually used (Linkerd)
linkerd viz tap -n app deploy/api | grep tls=true

# SPIFFE ID inspection (from Envoy sidecar)
kubectl exec -n app <pod> -c istio-proxy -- \
  openssl s_client -showcerts -connect <peer>:443 </dev/null \
  | openssl x509 -noout -text | grep URI

# Test denied call — should 403 with RBAC denied
kubectl exec -n app curl-test -- curl -v http://api.app
```

## Common operations

```bash
# Migrate STRICT mTLS gradually
# 1. Start PERMISSIVE
kubectl patch peerauthentication default -n istio-system --type=merge \
  -p '{"spec":{"mtls":{"mode":"PERMISSIVE"}}}'
# 2. Once 100% mTLS in metrics, flip
kubectl patch peerauthentication default -n istio-system --type=merge \
  -p '{"spec":{"mtls":{"mode":"STRICT"}}}'

# Allow only one ServiceAccount to call a service
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: { name: allow-frontend, namespace: app }
spec:
  selector: { matchLabels: { app: api } }
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/frontend"]
      to:
        - operation: { methods: [GET, POST], paths: [/api/*] }
EOF

# Restart sidecars to pick up new root CA
kubectl rollout restart deployment -n app
```

## Cleanup

```bash
kubectl delete authorizationpolicy --all -n app
kubectl delete peerauthentication default -n istio-system
istioctl uninstall --purge -y
linkerd uninstall | kubectl delete -f -
helm uninstall spire -n spire
kubectl delete ns istio-system linkerd spire
```

## One-liners worth memorising

```bash
# Verify mTLS in flight
istioctl authn tls-check <pod>.<ns>

# See workload SPIFFE identity
kubectl exec <pod> -c istio-proxy -- curl -s localhost:15000/certs | jq .

# Find pods missing the sidecar
kubectl get pods -A -o json \
  | jq -r '.items[] | select(.spec.containers | length == 1) | "\(.metadata.namespace)/\(.metadata.name)"'

# Generate the Envoy auth config for a pod (debug)
istioctl proxy-config listener <pod>.<ns> -o json | jq .
```
