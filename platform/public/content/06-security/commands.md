# Security · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."

---

## Pane 1 — Triage (first 5 minutes)

```bash
# Who has cluster-admin right now?
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | [.metadata.name, (.subjects[]?.name // "none")] | @tsv'

# Which pods are auto-mounting SA tokens (information disclosure risk)?
kubectl get pods -A -o json \
  | jq -r '.items[] | select(.spec.automountServiceAccountToken != false) | [.metadata.namespace, .metadata.name] | @tsv'

# Is audit logging enabled on the API server?
kubectl -n kube-system get pod -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep audit

# What Falco alerts fired in the last 10 minutes?
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=10m | grep -E "CRITICAL|WARNING"

# List NetworkPolicies (lack of any = open cluster)
kubectl get networkpolicies -A
```

---

## Pane 2 — RBAC Diagnosis

```bash
# What can a service account do?
kubectl auth can-i --list \
  --as=system:serviceaccount:payments:api-sa \
  -n payments

# Find all ClusterRoles with wildcard verbs
kubectl get clusterroles -o json \
  | jq -r '.items[] | .metadata.name as $r | .rules[]? | select(.verbs[] == "*") | $r'

# Find all ClusterRoles with wildcard resources
kubectl get clusterroles -o json \
  | jq -r '.items[] | .metadata.name as $r | .rules[]? | select(.resources[]? == "*") | $r'

# Who can read secrets in the payments namespace?
kubectl auth can-i get secrets -n payments --list-subjects 2>/dev/null || \
  kubectl get rolebindings,clusterrolebindings -A -o json \
  | jq -r '.items[] | select(.roleRef.name | test("secret|admin")) | [.metadata.namespace, .metadata.name, (.subjects[]?.name // "-")] | @tsv'

# Create a minimal role (least privilege template)
kubectl create role app-reader \
  --verb=get,list,watch \
  --resource=configmaps,secrets \
  --namespace=payments \
  --dry-run=client -o yaml

# Disable SA token auto-mount
kubectl patch serviceaccount default -n payments \
  -p '{"automountServiceAccountToken": false}'
```

---

## Pane 3 — Pod Security Admission

```bash
# Label a namespace for restricted enforcement
kubectl label namespace payments \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

# Dry-run: what would break if you enforce restricted today?
kubectl label namespace payments \
  pod-security.kubernetes.io/warn=restricted \
  --dry-run=server 2>&1

# Check current PSA labels on all namespaces
kubectl get namespaces -o json \
  | jq -r '.items[] | [.metadata.name, (.metadata.labels | to_entries[] | select(.key | startswith("pod-security")) | "\(.key)=\(.value)")] | @tsv'

# Test: attempt to run a privileged pod (should fail in restricted ns)
kubectl run badpod --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"badpod","image":"nginx","securityContext":{"privileged":true}}]}}' \
  -n payments --dry-run=server
```

---

## Pane 4 — NetworkPolicy

```bash
# Apply default-deny-all to a namespace
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: payments
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF

# Allow DNS egress (required after default-deny)
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: payments
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
EOF

# Test connectivity from a debug pod
kubectl run nettest --image=busybox --rm -it -n payments \
  -- sh -c "nc -zv postgres 5432; echo exit=$?"

# List all NetworkPolicies with their selectors
kubectl get networkpolicies -A -o custom-columns=\
'NS:.metadata.namespace,NAME:.metadata.name,POD-SELECTOR:.spec.podSelector'
```

---

## Pane 5 — Secret Management

```bash
# Seal a secret with Bitnami Sealed Secrets
kubectl create secret generic db-creds \
  --from-literal=password=hunter2 \
  --dry-run=client -o yaml \
  | kubeseal --format yaml > sealed-db-creds.yaml

# Fetch the sealing certificate (for offline sealing)
kubeseal --fetch-cert > pub-cert.pem
kubectl create secret generic mysecret --dry-run=client -o yaml \
  | kubeseal --cert pub-cert.pem --format yaml

# SOPS encrypt with age
age-keygen -o age.key
SOPS_AGE_KEY_FILE=age.key sops --encrypt \
  --age $(age-keygen -y age.key) secrets.yaml > secrets.enc.yaml
SOPS_AGE_KEY_FILE=age.key sops --decrypt secrets.enc.yaml | kubectl apply -f -

# Check ESO sync status
kubectl get externalsecrets -A
kubectl describe externalsecret db-password -n payments | grep -A5 Conditions

# Verify a Secret was created by ESO
kubectl get secret db-password -n payments \
  -o jsonpath='{.metadata.annotations.reconcile\.external-secrets\.io/data-hash}'
```

---

## Pane 6 — Image Scanning (Trivy + Grype)

```bash
# Quick scan — table output
trivy image nginx:1.25

# CI gate: exit 1 on CRITICAL or HIGH with a fix
trivy image --severity CRITICAL,HIGH --exit-code 1 nginx:1.25

# SARIF output for GitHub Code Scanning
trivy image --format sarif --output trivy-results.sarif nginx:1.25

# Scan from a tarball (air-gapped)
docker save nginx:1.25 | trivy image --input -

# Scan a running cluster for CVEs in deployed images
trivy k8s --report summary cluster

# Grype — alternative with SBOM input
grype nginx:1.25 --fail-on high
grype sbom:./sbom.spdx.json --output table

# Update Trivy's vulnerability database
trivy image --download-db-only
```

---

## Pane 7 — SBOM Generation (Syft)

```bash
# Generate SPDX JSON SBOM
syft nginx:1.25 -o spdx-json=sbom.spdx.json

# Generate CycloneDX JSON SBOM
syft nginx:1.25 -o cyclonedx-json=sbom.cdx.json

# Query the SBOM for a specific package
cat sbom.spdx.json | jq '.packages[] | select(.name == "openssl") | {name, versionInfo}'

# Count total packages in an image
cat sbom.spdx.json | jq '.packages | length'

# Attest SBOM to registry (keyless)
cosign attest \
  --predicate sbom.spdx.json \
  --type spdx \
  ghcr.io/myorg/myapp:v1.2.3

# Verify SBOM attestation exists
cosign verify-attestation \
  --type spdx \
  --certificate-identity-regexp "https://github.com/myorg/myapp" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/myorg/myapp:v1.2.3 | jq -r '.payload' | base64 -d | jq .
```

---

## Pane 8 — Image Signing (Cosign)

```bash
# Sign an image keylessly (in GitHub Actions OIDC context)
cosign sign --yes ghcr.io/myorg/myapp:v1.2.3

# Verify a signed image
cosign verify \
  --certificate-identity-regexp "https://github.com/myorg/myapp/.github/workflows/release.yml" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/myorg/myapp:v1.2.3

# Download and inspect the signature
cosign download signature ghcr.io/myorg/myapp:v1.2.3

# Check Rekor transparency log entry
cosign verify \
  --certificate-identity-regexp "https://github.com/myorg/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/myorg/myapp:v1.2.3 | jq '.[0].optional.Bundle.Payload.logIndex'

# Verify image with a static key (alternative to keyless)
cosign generate-key-pair
cosign sign --key cosign.key ghcr.io/myorg/myapp:v1.2.3
cosign verify --key cosign.pub ghcr.io/myorg/myapp:v1.2.3
```

---

## Pane 9 — SLSA Provenance

```bash
# Verify SLSA provenance for an image
slsa-verifier verify-image \
  ghcr.io/myorg/myapp@sha256:abc123 \
  --source-uri github.com/myorg/myapp \
  --source-tag v1.2.3

# Download and inspect provenance attestation
cosign download attestation ghcr.io/myorg/myapp:v1.2.3 \
  | jq -r '.payload' | base64 -d | jq '.predicate'

# Check SLSA level of the predicate
cosign download attestation ghcr.io/myorg/myapp:v1.2.3 \
  | jq -r '.payload' | base64 -d \
  | jq '.predicateType'
# Expected: "https://slsa.dev/provenance/v0.2"

# List all OCI artifacts attached to an image (signatures + attestations)
cosign triangulate ghcr.io/myorg/myapp:v1.2.3
```

---

## Pane 10 — OPA / Gatekeeper / Kyverno

```bash
# List all active Gatekeeper constraints and their violations
kubectl get constraints -A
kubectl describe requireresourcelimits require-cpu-limits | grep -A30 "Total Violations"

# List Kyverno policies and their status
kubectl get clusterpolicies
kubectl get policyreports -A

# Kyverno: test a policy against a resource (dry run)
kyverno apply ./policy.yaml --resource ./pod.yaml

# Gatekeeper: run audit manually
kubectl annotate -n gatekeeper-system pod -l control-plane=controller-manager \
  audit.gatekeeper.sh/last-run-time- 2>/dev/null; echo "audit triggered"

# Watch for Kyverno admission denials in real time
kubectl get events -A --watch | grep "kyverno"

# Export PolicyReport violations
kubectl get policyreports -A -o json \
  | jq -r '.items[].results[]? | select(.result == "fail") | [.policy, .rule, .resources[].name] | @tsv'
```

---

## Pane 11 — Runtime Security (Falco + Tetragon)

```bash
# Follow Falco alerts in real time
kubectl logs -n falco -l app.kubernetes.io/name=falco -f | grep -E "Critical|Warning"

# Count Falco alerts by rule in the last hour
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=1h \
  | jq -r '.rule' | sort | uniq -c | sort -rn | head -20

# Tetragon: watch all exec events cluster-wide
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents -o compact --event-types PROCESS_EXEC

# Tetragon: watch events in a specific namespace
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents -o compact --namespace payments

# Tetragon: watch network connections from a pod
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents -o compact --event-types PROCESS_KPROBE --namespace payments

# Replay Falco events from a capture file
falco -e /var/log/falco-capture.scap
```

---

## Pane 12 — Incident Response

```bash
# ISOLATE: blackhole a compromised pod by label
POD="api-7f9b8c-zrtpq"
NS="payments"
kubectl label pod $POD -n $NS incident=isolated

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-$POD
  namespace: $NS
spec:
  podSelector:
    matchLabels:
      incident: isolated
  policyTypes: [Ingress, Egress]
EOF

# SNAPSHOT: attach a forensic debug container
kubectl debug -it $POD -n $NS --image=ubuntu:22.04 --target=$(kubectl get pod $POD -n $NS -o jsonpath='{.spec.containers[0].name}') -- bash

# Inside debug container — capture evidence
# ps aux; ls -la /proc/1/fd; env | grep -iE "password|secret|key|token"; find / -newer /tmp -type f 2>/dev/null

# COLLECT: copy logs and events
kubectl logs $POD -n $NS --since=24h --all-containers > /tmp/ir/pod.log
kubectl get events -n $NS --sort-by='.lastTimestamp' > /tmp/ir/events.log

# FIND LATERAL MOVEMENT: check what other pods this SA can reach
SA=$(kubectl get pod $POD -n $NS -o jsonpath='{.spec.serviceAccountName}')
kubectl auth can-i --list --as=system:serviceaccount:$NS:$SA

# REMEDIATE: delete pod and rotate secrets
kubectl delete pod $POD -n $NS
kubectl delete secret --all -n $NS   # rotate ALL secrets in namespace
kubectl rollout restart deployment -n $NS

# POSTMORTEM: extract full audit log for the incident window
# (requires audit log access from API server nodes or SIEM)
grep "\"user\":{\"username\":\"system:serviceaccount:$NS:$SA\"}" /var/log/kubernetes/audit.log \
  | jq -r '[.requestReceivedTimestamp, .verb, .objectRef.resource, .objectRef.name] | @tsv'
```

---

## Quick Reference — Tool Matrix

| Task | Tool | Command |
|------|------|---------|
| Scan image CVEs | trivy | `trivy image --severity CRITICAL,HIGH --exit-code 1 IMAGE` |
| Alternative scan | grype | `grype IMAGE --fail-on high` |
| Generate SBOM | syft | `syft IMAGE -o spdx-json=sbom.json` |
| Sign image | cosign | `cosign sign --yes IMAGE` |
| Verify signature | cosign | `cosign verify --certificate-identity-regexp ... IMAGE` |
| SLSA verify | slsa-verifier | `slsa-verifier verify-image IMAGE@digest --source-uri ...` |
| Policy audit | kyverno | `kubectl get policyreports -A` |
| Policy audit | gatekeeper | `kubectl get constraints -A` |
| Runtime alerts | falco | `kubectl logs -n falco -l ...falco -f` |
| Runtime trace | tetragon | `tetra getevents -o compact` |
| RBAC check | kubectl | `kubectl auth can-i --list --as=system:serviceaccount:NS:SA` |
| Secret seal | kubeseal | `kubectl ... --dry-run=client -o yaml \| kubeseal` |
| Isolate pod | kubectl | `kubectl label pod POD incident=isolated && kubectl apply -f deny-all.yaml` |
