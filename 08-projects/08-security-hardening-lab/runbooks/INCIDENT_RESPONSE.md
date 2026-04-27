# Incident Response Runbook — Security Hardening Lab

## Overview

This runbook covers the four phases of a Kubernetes security incident. Each phase has clear entry conditions, ordered steps, and exit criteria. An on-call engineer with no prior context on the incident should be able to execute this runbook start to finish.

**Scope:** Container escape, anomalous pod behavior, detected Falco alert, unexpected RBAC change, or supply-chain compromise.

**Time objective:** Containment within 30 minutes. Investigation complete within 4 hours.

---

## Phase 1 — Isolate (Target: T+0 to T+15 min)

Goal: stop the bleeding without destroying evidence.

### 1.1 Confirm the alert

```bash
# Check Falco alerts for the affected pod
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=30m \
  | grep -E "(CRITICAL|ERROR|WARNING)" \
  | grep "<AFFECTED_POD_NAME>"

# Check Kubernetes audit log for recent API activity from the SA
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp' | tail -20

# Check who recently modified RBAC
kubectl get clusterrolebindings,rolebindings -A \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' \
  | sort -k2 -r | head -20
```

### 1.2 Isolate the pod with a deny-all NetworkPolicy

```bash
# Apply an emergency NetworkPolicy that denies all traffic to/from the pod
# Replace AFFECTED_POD_LABEL with the pod's label selector
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-isolate
  namespace: <NAMESPACE>
spec:
  podSelector:
    matchLabels:
      app: <AFFECTED_POD_LABEL>
  policyTypes: [Ingress, Egress]
  # No ingress/egress rules = deny all
EOF
```

### 1.3 Cordon the node (if container escape is suspected)

```bash
# Prevent new pods from scheduling on the potentially compromised node
kubectl cordon <NODE_NAME>

# List the node to confirm it is SchedulingDisabled
kubectl get node <NODE_NAME>
# STATUS → Ready,SchedulingDisabled

# Do NOT drain yet — draining destroys evidence (pod logs, ephemeral storage)
```

### 1.4 Preserve the ServiceAccount token (revoke if compromised)

```bash
# List all secrets for the SA
kubectl get secrets -n <NAMESPACE> \
  | grep <SERVICE_ACCOUNT_NAME>

# If the SA token was leaked, delete it — Kubernetes will recreate a new one
# The old token becomes invalid immediately
kubectl delete secret <SA_TOKEN_SECRET_NAME> -n <NAMESPACE>
```

**Exit criteria for Phase 1:**
- [ ] Affected pod is network-isolated
- [ ] Affected node is cordoned
- [ ] Alert is confirmed (not a false positive)
- [ ] Incident channel opened, on-call lead notified

---

## Phase 2 — Snapshot (Target: T+15 to T+30 min)

Goal: preserve evidence before any cleanup. Evidence is perishable.

### 2.1 Capture pod state

```bash
# Full pod spec and status
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml > /tmp/incident-pod-spec.yaml

# Describe output (events, conditions, volume mounts)
kubectl describe pod <POD_NAME> -n <NAMESPACE> > /tmp/incident-pod-describe.txt

# Container logs (stdout/stderr from app)
kubectl logs <POD_NAME> -n <NAMESPACE> --all-containers=true \
  > /tmp/incident-pod-logs.txt

# Previous container logs (if the container restarted)
kubectl logs <POD_NAME> -n <NAMESPACE> --previous \
  > /tmp/incident-pod-logs-previous.txt 2>/dev/null || true
```

### 2.2 Capture node state (requires node SSH or privileged debug pod)

```bash
# Spawn a debug container on the node (non-destructive, read-only)
kubectl debug node/<NODE_NAME> -it \
  --image=ubuntu:22.04 \
  -- bash -c "
    # Capture running processes
    ps auxf > /host/tmp/incident-ps.txt;
    # Capture network connections
    ss -tnp > /host/tmp/incident-ss.txt;
    # Capture recent systemd journal
    journalctl --since '1h ago' > /host/tmp/incident-journal.txt;
    # List recently modified files (last 2 hours)
    find / -newer /tmp -type f -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null \
      > /host/tmp/incident-modified-files.txt;
  "
```

### 2.3 Capture Falco event stream

```bash
# Export all Falco events from the last hour as JSON
kubectl logs -n falco -l app.kubernetes.io/name=falco \
  --since=1h \
  | grep -E '"rule":' \
  > /tmp/incident-falco-events.jsonl
```

### 2.4 Capture RBAC and network state

```bash
# All ClusterRoleBindings (look for unexpected additions)
kubectl get clusterrolebindings -o yaml > /tmp/incident-crb.yaml

# All NetworkPolicies in the affected namespace
kubectl get networkpolicies -n <NAMESPACE> -o yaml > /tmp/incident-netpol.yaml

# Current ServiceAccounts and their secrets
kubectl get serviceaccounts -n <NAMESPACE> -o yaml > /tmp/incident-sa.yaml
```

**Exit criteria for Phase 2:**
- [ ] Pod spec, logs, and events captured
- [ ] Node process list and network state captured
- [ ] Falco event stream captured
- [ ] RBAC snapshot saved
- [ ] All artifacts stored in secure, immutable location (S3 with Object Lock, or similar)

---

## Phase 3 — Investigate (Target: T+30 min to T+4h)

Goal: determine root cause, blast radius, and attacker capabilities.

### 3.1 Identify the attack entry point

```bash
# Review Falco events chronologically
cat /tmp/incident-falco-events.jsonl \
  | jq -r '[.time, .priority, .rule, .output] | @tsv' \
  | sort

# Look for the FIRST anomalous event — that is the entry point
# Common patterns:
#   exec_in_container → initial shell access
#   unexpected_outbound → C2 callback or data exfiltration
#   write_etc_dir → persistence installation
#   privilege_escalation_attempt → escalation after initial access
```

### 3.2 Check the supply chain (was a malicious image deployed?)

```bash
# Verify the image signature for every container in the affected pod
IMAGES=$(kubectl get pod <POD_NAME> -n <NAMESPACE> \
  -o jsonpath='{.spec.containers[*].image}')

for IMAGE in $IMAGES; do
  echo "Verifying: $IMAGE"
  COSIGN_EXPERIMENTAL=1 cosign verify \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --certificate-identity-regexp="^https://github.com/YOUR_ORG/" \
    "$IMAGE" && echo "PASS" || echo "FAIL — image may not be from trusted CI"
done
```

### 3.3 Determine blast radius

```bash
# What namespaces could the compromised SA access?
kubectl auth can-i --list \
  --as=system:serviceaccount:<NAMESPACE>:<SA_NAME> \
  --all-namespaces

# What secrets could it read?
kubectl auth can-i get secrets \
  --as=system:serviceaccount:<NAMESPACE>:<SA_NAME> -A

# Were any Vault leases granted to this SA?
# (requires Vault CLI access)
vault list auth/kubernetes/role/<ROLE_NAME>/token-policies
vault token lookup <TOKEN_IF_KNOWN>

# Check if the attacker created any new resources
kubectl get all -A --sort-by='.metadata.creationTimestamp' \
  | tail -50
```

### 3.4 Determine data exposure

```bash
# Check environment variables for exposed secrets (from the pod spec snapshot)
cat /tmp/incident-pod-spec.yaml \
  | grep -A5 "env:" \
  | grep -E "(value|secretKeyRef)"

# Check if any Kubernetes Secrets were read recently (requires audit log)
# Audit log query (example for CloudWatch Logs):
# fields @timestamp, @message
# | filter objectRef.resource = "secrets" and verb = "get"
# | filter sourceIPs like "<ATTACKER_IP>"
# | sort @timestamp desc
```

**Exit criteria for Phase 3:**
- [ ] Attack entry point identified (CVE, misconfiguration, or credential theft)
- [ ] Blast radius documented (what the attacker could access)
- [ ] Data exposure assessed (what was read, modified, or exfiltrated)
- [ ] Timeline reconstructed from Falco events + audit log

---

## Phase 4 — Remediate (Target: T+4h to T+24h)

Goal: remove the attacker, fix the root cause, harden against recurrence.

### 4.1 Evict and replace the affected workload

```bash
# Delete the compromised pod (Deployment controller will recreate from clean image)
kubectl delete pod <POD_NAME> -n <NAMESPACE>

# If the Deployment itself was modified by the attacker, redeploy from git
git checkout HEAD -- hardened/secure-deployment.yaml
kubectl apply -f hardened/secure-deployment.yaml

# Verify the new pod starts clean
kubectl get pods -n <NAMESPACE> -w
```

### 4.2 Rotate compromised credentials

```bash
# If database credentials may have been exposed:
# 1. Generate new credentials in Vault
vault write database/rotate-root/<DB_ROLE>

# 2. Force External Secrets Operator to refresh
kubectl annotate externalsecret app-secrets \
  force-sync="$(date +%s)" \
  -n <NAMESPACE>

# 3. Restart the workload to pick up new credentials
kubectl rollout restart deployment/secure-app -n <NAMESPACE>
```

### 4.3 Fix the root cause

Based on the Phase 3 investigation, apply the relevant fix:

| Root Cause | Fix |
|------------|-----|
| Image with CVE | Update base image; re-scan with Trivy; redeploy |
| Overly permissive RBAC | Apply `hardened/secure-rbac.yaml`; run `kubectl auth can-i` verification |
| Missing PSA labels | Apply `pod-security.kubernetes.io/enforce=restricted` to namespace |
| Unsigned/unverified image | Enable `require-image-digest` Kyverno policy; cosign verify in CI |
| Exposed secret in env | Migrate to External Secrets Operator + Vault |
| hostPath mount | Apply `restrict-hostpath` Kyverno policy |

### 4.4 Uncordon the node (after OS-level remediation if needed)

```bash
# Remove emergency NetworkPolicy isolation
kubectl delete networkpolicy emergency-isolate -n <NAMESPACE>

# Uncordon the node only after confirming it is clean
kubectl uncordon <NODE_NAME>
```

### 4.5 Post-incident verification

```bash
# Run the full audit script to confirm all controls are back in place
./tests/audit.sh

# Re-run kube-bench to confirm CIS score is maintained
make kube-bench

# Verify Falco is running and custom rules are loaded
kubectl get pods -n falco
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep "Loading" | tail -5
```

### 4.6 Post-incident report

Write a post-incident report covering:

1. **Timeline** — when did the incident start, when was it detected, when was it contained?
2. **Root cause** — what control failed and why?
3. **Impact** — what data or systems were exposed?
4. **Actions taken** — isolation, rotation, redeployment steps
5. **Prevention** — what policy or control change prevents recurrence?
6. **Detection gap** — did we detect this fast enough? What alert would have fired sooner?

**Exit criteria for Phase 4:**
- [ ] Compromised workload replaced with clean image
- [ ] All credentials that may have been exposed rotated
- [ ] Root cause remediated (not just the symptom)
- [ ] `audit.sh` passes all checks
- [ ] Post-incident report filed within 24 hours

---

## Quick Reference

```
ISOLATE   → NetworkPolicy deny-all + cordon node
SNAPSHOT  → pod yaml + logs + Falco events + RBAC state
INVESTIGATE → Falco timeline + cosign verify + blast radius
REMEDIATE  → delete pod + rotate creds + fix root cause + audit-all
```

## Related Resources

- [`tests/audit.sh`](../tests/audit.sh) — automated security checks
- [`runtime/falco-rules.yaml`](../runtime/falco-rules.yaml) — detection rules
- [`hardened/secure-deployment.yaml`](../hardened/secure-deployment.yaml) — clean deployment
- [NIST SP 800-61r2](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf) — incident response guide
