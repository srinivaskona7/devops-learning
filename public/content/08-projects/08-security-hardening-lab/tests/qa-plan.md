# QA Plan — Security Hardening Lab

> **Instructions for the QA engineer:** Work through each item in order. Mark PASS or FAIL. Every FAIL must have a remediation action before signing off. A cluster is not "hardened" until all 30 items are PASS.

---

## Phase 1 — RBAC (Items 1–6)

| # | Test | Command | Expected Result | Pass? |
|---|------|---------|----------------|-------|
| 1 | No ClusterRoleBinding grants cluster-admin to a workload SA | `kubectl get clusterrolebindings -o json \| jq '.items[] \| select(.roleRef.name=="cluster-admin") \| .subjects[] \| select(.kind=="ServiceAccount")'` | Empty output | |
| 2 | secure-sa cannot perform wildcard verbs | `kubectl auth can-i '*' '*' --as=system:serviceaccount:production:secure-sa` | `no` | |
| 3 | secure-sa cannot delete pods | `kubectl auth can-i delete pods --as=system:serviceaccount:production:secure-sa -n production` | `no` | |
| 4 | secure-sa cannot read secrets | `kubectl auth can-i get secrets --as=system:serviceaccount:production:secure-sa -n production` | `no` | |
| 5 | secure-sa CAN read its named ConfigMap | `kubectl auth can-i get configmaps/secure-app-config --as=system:serviceaccount:production:secure-sa -n production` | `yes` | |
| 6 | automountServiceAccountToken is false on secure-sa | `kubectl get sa secure-sa -n production -o jsonpath='{.automountServiceAccountToken}'` | `false` | |

---

## Phase 2 — Pod Security Admission (Items 7–10)

| # | Test | Command | Expected Result | Pass? |
|---|------|---------|----------------|-------|
| 7 | Namespace has PSA restricted enforce label | `kubectl get ns production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'` | `restricted` | |
| 8 | Pod running as root is rejected by PSA | Apply a pod with `runAsUser: 0` to the `production` namespace | AdmissionDenied error | |
| 9 | Privileged pod is rejected by PSA | Apply a pod with `privileged: true` to `production` | AdmissionDenied error | |
| 10 | Pod with hostNetwork is rejected by PSA | Apply a pod with `hostNetwork: true` to `production` | AdmissionDenied error | |

**Manual test for items 8–10:**
```bash
# Create a test manifest and attempt to apply it
cat <<EOF | kubectl apply -f - 2>&1 | grep -E "(Error|denied)"
apiVersion: v1
kind: Pod
metadata:
  name: psa-test
  namespace: production
spec:
  containers:
  - name: test
    image: nginx@sha256:a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4
    securityContext:
      runAsUser: 0     # should be rejected
      runAsNonRoot: false
EOF
```

---

## Phase 3 — Kyverno Policies (Items 11–18)

| # | Test | Policy Tested | Expected Result | Pass? |
|---|------|--------------|----------------|-------|
| 11 | Pod with `runAsNonRoot: false` rejected | require-non-root | Policy violation: `check-pod-run-as-non-root` | |
| 12 | Pod with `runAsUser: 0` rejected | require-non-root | Policy violation: `check-container-run-as-non-root` | |
| 13 | Pod without CPU limits rejected | require-resource-limits | Policy violation: `check-container-resource-limits` | |
| 14 | Pod without memory limits rejected | require-resource-limits | Policy violation: `check-container-resource-limits` | |
| 15 | Pod with `allowPrivilegeEscalation: true` rejected | deny-privilege-escalation | Policy violation: `deny-privilege-escalation-containers` | |
| 16 | Pod with image by tag (`:latest`) rejected | require-image-digest | Policy violation: `require-digest-containers` | |
| 17 | Pod with `hostPath` volume rejected | restrict-hostpath | Policy violation: `deny-hostpath-volumes` | |
| 18 | All 5 policies are in Enforce mode | `kubectl get clusterpolicies -o jsonpath='{.items[*].spec.validationFailureAction}'` | `Enforce Enforce Enforce Enforce Enforce` | |

---

## Phase 4 — NetworkPolicy (Items 19–22)

| # | Test | Command | Expected Result | Pass? |
|---|------|---------|----------------|-------|
| 19 | default-deny-all NetworkPolicy exists | `kubectl get networkpolicies default-deny-all -n production` | Policy found | |
| 20 | Pod cannot reach cross-namespace service | `kubectl exec -n production test-pod -- curl -s --max-time 3 http://kube-dns.kube-system:53` | Connection timeout (exit 28) | |
| 21 | Pod cannot reach arbitrary external IP | `kubectl exec -n production test-pod -- curl -s --max-time 3 http://1.1.1.1` | Connection timeout | |
| 22 | Declared allowed internal path works | `kubectl exec -n production frontend-pod -- curl -s http://secure-app:80/healthz` | `{"status":"ok"}` | |

---

## Phase 5 — Supply Chain (Items 23–26)

| # | Test | Command | Expected Result | Pass? |
|---|------|---------|----------------|-------|
| 23 | Trivy scan returns 0 HIGH/CRITICAL | `make scan IMAGE_REF=<IMAGE>` | `SCAN RESULT: PASS` | |
| 24 | Image has valid cosign keyless signature | `make verify IMAGE_REF=<IMAGE>` | Signature verified, Rekor entry shown | |
| 25 | CycloneDX SBOM attestation is present | `cosign verify-attestation --type cyclonedx <IMAGE>` | Attestation verified, component count > 0 | |
| 26 | Unsigned image is rejected by cosign verify | `cosign verify <UNSIGNED_IMAGE>` | `Error: no signatures found` | |

---

## Phase 6 — Runtime Detection (Items 27–28)

| # | Test | Steps | Expected Result | Pass? |
|---|------|-------|----------------|-------|
| 27 | Falco fires `exec_in_container` within 2 s of shell exec | 1. `kubectl exec -n production <POD> -- /bin/sh -c "id"` 2. Watch `kubectl logs -n falco -l app.kubernetes.io/name=falco` | `WARNING exec_in_container: ...` appears within 2 s | |
| 28 | Falco fires `write_etc_dir` on write to /etc | 1. `kubectl exec -n production <POD> -- touch /etc/pwned` 2. Watch Falco logs | `ERROR write_etc_dir: ...` appears | |

---

## Phase 7 — kube-bench CIS Benchmark (Item 29)

| # | Test | Command | Expected Result | Pass? |
|---|------|---------|----------------|-------|
| 29 | CIS Kubernetes Benchmark score ≥ 85 % | `make kube-bench` | ≥ 85 PASS out of 100 checks | |

---

## Phase 8 — Incident Response (Item 30)

| # | Test | Steps | Expected Result | Pass? |
|---|------|-------|----------------|-------|
| 30 | Runbook covers all four phases with actionable steps | Manual review of `runbooks/INCIDENT_RESPONSE.md` | All four phases (Isolate, Snapshot, Investigate, Remediate) have: entry condition, ordered steps, exit criteria | |

---

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Security Engineer | | | |
| Platform Engineer | | | |
| Team Lead | | | |

**Total: __ / 30 PASS**

A cluster is considered hardened when all 30 items are PASS. Any FAIL must have a linked remediation issue before sign-off.
