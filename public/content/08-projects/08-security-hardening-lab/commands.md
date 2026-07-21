# Project 08 (Security Hardening Lab) — Commands

> Quick pickup reference. Full walkthrough in `README.md` and `checklist.md`.

## Prerequisites
```bash
kubectl get nodes
helm version
trivy --version || brew install trivy
gh auth status
aws sts get-caller-identity
```

## Build
Nothing to compile — Helm + manifests + AWS IAM only.

## Deploy
```bash
# 1. CIS benchmark with kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-eks.yaml
kubectl wait --for=condition=complete job/kube-bench --timeout=120s
kubectl logs job/kube-bench | tee cis-report.txt

# 2. Kyverno + baseline policies
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
  --version 3.2.6 --wait

kubectl apply -f https://raw.githubusercontent.com/kyverno/policies/main/pod-security/baseline/disallow-host-namespaces/disallow-host-namespaces.yaml
kubectl apply -f https://raw.githubusercontent.com/kyverno/policies/main/pod-security/restricted/require-run-as-non-root-user/require-run-as-non-root-user.yaml
kubectl apply -f https://raw.githubusercontent.com/kyverno/policies/main/best-practices/disallow-latest-tag/disallow-latest-tag.yaml

# 3. trivy-operator
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  -n trivy-system --create-namespace \
  --version 0.24.1 \
  --set trivy.severity=HIGH,CRITICAL --wait

# 4. Default-deny NetworkPolicy on proj01
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: proj01 }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-ingress-and-dns, namespace: proj01 }
spec:
  podSelector: { matchLabels: { app: hello-world } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: ingress-nginx } }
      ports: [{ port: 8080, protocol: TCP }]
  egress:
    - to:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } }
      ports:
        - { port: 53, protocol: UDP }
        - { port: 53, protocol: TCP }
EOF

# 5. GitHub OIDC -> AWS (one-time per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
# Then create the IAM role + trust per README Step 5.
```

## Verify
```bash
# CIS
grep -c FAIL cis-report.txt

# Kyverno blocks bad pods
kubectl run nope --image=nginx              # blocked: latest tag
kubectl run priv --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"priv","image":"nginx:1.27","securityContext":{"privileged":true}}]}}'
# blocked: privileged
kubectl run good --image=nginx:1.27         # allowed

# Trivy reports
kubectl get vulnerabilityreports -A | head
kubectl get configauditreports   -A | head

# NetworkPolicy denies arbitrary egress
kubectl -n proj01 run probe --image=busybox --restart=Never --rm -it -- \
  wget -qO- --timeout=3 http://1.1.1.1     # should TIMEOUT

# OIDC: a workflow with id-token: write running this works without static keys
#   - uses: aws-actions/configure-aws-credentials@v4
#     with: { role-to-assume: arn:aws:iam::ACCT:role/GhaDeployer, aws-region: us-east-1 }
#   - run: aws sts get-caller-identity
```

## Cleanup
```bash
helm -n trivy-system uninstall trivy-operator
helm -n kyverno      uninstall kyverno
kubectl delete clusterpolicy --all
kubectl -n proj01 delete networkpolicy --all
kubectl delete job kube-bench
kubectl delete pod nope good 2>/dev/null || true
rm -f cis-report.txt

# Remove OIDC role only if no longer needed
aws iam detach-role-policy --role-name GhaDeployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam delete-role --role-name GhaDeployer
```

## One-liners worth memorising
```bash
# Re-run kube-bench after fixing FAILs
kubectl delete job kube-bench && \
  kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-eks.yaml

# Test a Kyverno policy in dry-run before enforcing
kubectl apply --dry-run=server -f my-policy.yaml

# Highest-severity vulns across the cluster
kubectl get vulnerabilityreports -A -o json \
  | jq -r '.items[].report.vulnerabilities[] | select(.severity=="CRITICAL") | .vulnerabilityID' | sort -u

# Show effective NetworkPolicies for a pod (requires cilium/calicoctl)
kubectl describe networkpolicy -n proj01

# Trivy local image scan, block on HIGH/CRITICAL
trivy image --severity HIGH,CRITICAL --exit-code 1 ghcr.io/$GH_USER/hello-world:latest
```
