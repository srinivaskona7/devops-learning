# Admission Controllers — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
# List enabled admission plugins (works on kubeadm clusters)
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml \
  | grep -E 'enable-admission-plugins|disable-admission-plugins'
```

## Apply manifests

```bash
kubectl apply -f kyverno-policy.yaml
kubectl apply -f opa-constraint.yaml
```

## Install Kyverno

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl -n kyverno get pods
kubectl get clusterpolicy
```

## Install OPA Gatekeeper

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper/gatekeeper --name-template=gatekeeper \
  --namespace gatekeeper-system --create-namespace
kubectl -n gatekeeper-system get pods
kubectl get constrainttemplate
kubectl get constraint
```

## Inspect / verify

```bash
# Webhook configurations
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
kubectl describe validatingwebhookconfiguration <name>

# ValidatingAdmissionPolicy (CEL, in-process, GA 1.30)
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding

# Kyverno policy reports
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

## Test a policy (Kyverno dry-run / Gatekeeper test)

```bash
# Apply a violating manifest and watch it fail
kubectl apply -f bad-pod.yaml --dry-run=server

# Kyverno CLI
kyverno apply ./policy.yaml --resource ./pod.yaml
kyverno test ./tests/

# Gatekeeper CLI (gator)
gator test --filename=./constraints --filename=./resource.yaml
```

## Common operations

```bash
# Disable a webhook temporarily by label/scope
kubectl patch validatingwebhookconfiguration <name> --type=json \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'

# Logs
kubectl -n kyverno logs -l app.kubernetes.io/component=admission-controller --tail=100
kubectl -n gatekeeper-system logs -l control-plane=controller-manager --tail=100
```

## Cleanup

```bash
kubectl delete -f kyverno-policy.yaml -f opa-constraint.yaml --ignore-not-found
helm uninstall kyverno -n kyverno
helm uninstall gatekeeper -n gatekeeper-system
```

## One-liners worth memorising

```bash
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
kubectl get clusterpolicy                       # Kyverno
kubectl get constraint                          # Gatekeeper
kubectl apply -f bad.yaml --dry-run=server      # check policy without persisting
kubectl get validatingadmissionpolicy
```
