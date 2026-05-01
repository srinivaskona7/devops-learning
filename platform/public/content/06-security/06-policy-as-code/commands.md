# Policy as Code — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Kyverno CLI (test policies in CI)
brew install kyverno

# OPA Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  --name-template=gatekeeper -n gatekeeper-system --create-namespace

# Conftest (Rego unit tests)
brew install conftest
```

## Apply policies / manifests

```bash
# Kyverno cluster policies
kubectl apply -f kyverno-require-labels.yaml
kubectl apply -f kyverno-disallow-latest.yaml

# OPA Gatekeeper — ConstraintTemplate first, then Constraint
kubectl apply -f gatekeeper-template.yaml      # ConstraintTemplate
kubectl apply -f gatekeeper-constraint.yaml    # Constraint instance

# Built-in CEL ValidatingAdmissionPolicy (no webhook)
kubectl apply -f - <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: { name: deny-latest-tag }
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE","UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: "Image tag :latest is not allowed."
EOF
```

## Inspect / verify

```bash
# Kyverno
kubectl get clusterpolicy
kubectl describe clusterpolicy require-labels
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Test policies offline (CI)
kyverno test ./policies/
kyverno apply ./policies/ --resource ./manifests/bad-pod.yaml

# Gatekeeper
kubectl get constrainttemplates
kubectl get constraints
kubectl describe k8srequiredlabels require-team-label

# Conftest (OPA / Rego)
conftest test --policy ./policies ./manifests/

# Try to violate a policy and watch admission reject
kubectl run bad --image=nginx:latest    # blocked by disallow-latest
kubectl run bad --image=nginx:1.27       # also blocked if labels missing
```

## Common operations

```bash
# Audit existing workloads against new policy without enforcing
kubectl apply -f kyverno-require-labels.yaml   # spec.validationFailureAction: Audit

# Generate a PolicyException for a known-violating workload
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v2
kind: PolicyException
metadata: { name: legacy-app-exception, namespace: legacy }
spec:
  exceptions:
    - policyName: require-labels
      ruleNames: [check-team]
  match:
    any:
      - resources: { kinds: [Pod], namespaces: [legacy] }
EOF

# Bump enforcement after audit window is clean
kubectl patch clusterpolicy require-labels --type=merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

## Cleanup

```bash
kubectl delete clusterpolicy --all
kubectl delete constraints --all -A
kubectl delete constrainttemplates --all
kubectl delete validatingadmissionpolicy deny-latest-tag
helm uninstall kyverno -n kyverno
helm uninstall gatekeeper -n gatekeeper-system
```

## One-liners worth memorising

```bash
# Show every policy violation across cluster
kubectl get clusterpolicyreport -o json \
  | jq '.results[] | select(.result=="fail")'

# Test all policies in a repo against all manifests
kyverno test ./

# Find all pods that would violate a single policy (dry-run)
kyverno apply policy.yaml --cluster

# Gatekeeper audit results (non-enforced violations)
kubectl get k8srequiredlabels -o json | jq '.items[].status.violations'
```
