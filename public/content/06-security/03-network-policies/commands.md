# Network Policies — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Confirm the CNI actually enforces NetworkPolicy
kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'

# Create namespaces and label them so selectors can target by name
kubectl create namespace app
kubectl create namespace db
kubectl label namespace app name=app
kubectl label namespace db  name=db   tier=prod

# Two test pods to verify connectivity
kubectl run client --image=nicolaka/netshoot -n app -- sleep 1d
kubectl run server --image=nginx --port=80 -n db --labels='role=db'
kubectl expose pod server -n db --port=80
```

## Apply policies / manifests

```bash
# Default-deny — block ALL ingress + egress in a namespace
kubectl apply -f default-deny.yaml -n app

# Allow ingress from one namespace
kubectl apply -f allow-from-namespace.yaml -n db

# Allow egress to kube-dns (must-have, otherwise DNS breaks)
kubectl apply -f egress-to-dns.yaml -n app
```

## Inspect / verify

```bash
# List policies in a namespace
kubectl get networkpolicy -n app
kubectl get netpol -A
kubectl describe netpol default-deny -n app

# Test connectivity — before policy: works; after default-deny: hangs
kubectl exec -n app client -- curl -m 5 http://server.db.svc.cluster.local

# DNS check after egress policy applied
kubectl exec -n app client -- nslookup kubernetes.default

# Cilium-specific: trace policy decisions
kubectl exec -n kube-system ds/cilium -- cilium monitor --type policy-verdict
kubectl exec -n kube-system ds/cilium -- cilium endpoint list

# Calico-specific: see compiled rules
kubectl exec -n kube-system -l k8s-app=calico-node -- calicoctl get networkpolicy -A
```

## Common operations

```bash
# Render YAML for a default-deny without writing a file
cat <<EOF | kubectl apply -n app -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF

# Allow egress to API server CIDR (find the CIDR first)
kubectl get endpoints kubernetes -n default

# Temporarily disable a policy without deleting (rename selector to no-match)
kubectl patch netpol restrictive -n app --type=json \
  -p='[{"op":"replace","path":"/spec/podSelector/matchLabels","value":{"disabled":"true"}}]'
```

## Cleanup

```bash
kubectl delete netpol --all -n app
kubectl delete netpol --all -n db
kubectl delete pod client -n app
kubectl delete pod server svc/server -n db
kubectl delete namespace app db
```

## One-liners worth memorising

```bash
# Default-deny everywhere (run once per namespace)
for ns in $(kubectl get ns -o name | grep -v kube-); do
  kubectl apply -n "${ns##*/}" -f default-deny.yaml
done

# Verify CNI actually denies — should fail after default-deny
kubectl exec -n app client -- timeout 3 curl http://server.db

# List every pod NOT covered by any NetworkPolicy (rough heuristic)
kubectl get pods -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"'
```
