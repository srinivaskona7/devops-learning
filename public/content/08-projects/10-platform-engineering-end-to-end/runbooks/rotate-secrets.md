# Runbook: Rotate Secrets

**Audience:** Platform engineers, security team
**Frequency:** Quarterly (or immediately after a suspected credential leak)
**Time to complete:** 15–30 minutes per service

---

## Overview

The platform uses Vault + External Secrets Operator (ESO) for automated secret rotation. This runbook covers:

1. Routine rotation (ESO-automated, 1h cycle)
2. Manual emergency rotation (credential compromise)
3. Vault master key rotation
4. Platform TLS certificate rotation

---

## Scenario 1: Routine automated rotation (verify it's working)

ESO rotates secrets automatically every 1 hour. This procedure verifies rotation is healthy.

```bash
# Check ESO controller is running
kubectl get pods -n external-secrets
# All pods should be Running

# Check sync status for all ExternalSecrets
kubectl get externalsecret --all-namespaces

# Look for any not in SecretSynced status:
kubectl get externalsecret --all-namespaces \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.status.conditions[?(@.type=="Ready")].reason}{"\n"}{end}'

# If any show "SecretSyncedError", check the event:
kubectl describe externalsecret -n <namespace> <name>
```

If rotation is failing, see troubleshooting at the end of this runbook.

---

## Scenario 2: Emergency rotation — suspected credential compromise

**Trigger:** Security alert, leaked secret in git, suspected breach.

### Step 1: Identify which secret was compromised

```bash
# Check git history for accidentally committed secrets
git log --all --full-history --oneline
git secrets --scan  # if git-secrets is installed

# Check recent CI logs for secret exposure
# Look for any VAULT_ or K8s secret values in CI output
```

### Step 2: Immediately revoke the compromised credential in Vault

```bash
# Authenticate as a Vault admin (requires elevated token)
vault auth login -method=token token=$VAULT_ADMIN_TOKEN

# List current secrets for the service
vault kv get secret/<service-name>

# Generate a new secret immediately
vault kv put secret/<service-name> \
  db_password=$(openssl rand -base64 32) \
  api_key=$(openssl rand -hex 32) \
  jwt_secret=$(openssl rand -base64 64)

# Verify the new secret is stored
vault kv get secret/<service-name>
```

### Step 3: Force ESO to sync immediately

```bash
SERVICE=payment-service
NS=payment

# Force immediate sync (adds a timestamp annotation that triggers reconciliation)
kubectl annotate externalsecret $SERVICE-secrets -n $NS \
  force-sync=$(date +%s) --overwrite

# Watch the sync
kubectl get externalsecret -n $NS $SERVICE-secrets -w
# Should show SecretSynced within 10 seconds
```

### Step 4: Trigger a rolling restart to inject new secrets

```bash
# The ExternalSecret controller will update the K8s Secret.
# Pods only get new values on restart. Trigger a rolling restart:
kubectl argo rollouts restart $SERVICE -n $NS

# Watch rollout
kubectl argo rollouts get rollout $SERVICE -n $NS --watch

# Alternative if using Deployment:
kubectl rollout restart deployment/$SERVICE -n $NS
kubectl rollout status deployment/$SERVICE -n $NS
```

### Step 5: Revoke all existing Vault tokens for that service

```bash
# List leases for the service's Vault role
vault list auth/kubernetes/role

# Revoke all tokens for the compromised role
vault token revoke -mode=path auth/kubernetes/role/$SERVICE

# Force re-authentication (pods will re-auth on next ESO sync)
kubectl rollout restart deployment/external-secrets -n external-secrets
```

### Step 6: Verify the old credential no longer works

```bash
# Test: try to authenticate with the old credential
# (This test depends on the credential type)
# For a database password: try connecting with old password → should fail
# For an API key: make an API call with old key → should return 401
```

---

## Scenario 3: Vault unseal key rotation

Vault uses Shamir's Secret Sharing. The master key is split into 5 shares; any 3 can unseal.

```bash
# Current unseal key shares are stored in:
# - Vault operator (HSM or cloud KMS in production)
# - For local/dev: ~/.vault-init.json (NOT in git)

# Step 1: Re-key (generate new unseal key shares)
vault operator rekey \
  -init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > /tmp/vault-rekey-init.json

NONCE=$(cat /tmp/vault-rekey-init.json | jq -r '.nonce')

# Step 2: Provide existing key shares to authorize re-key
# (Each key holder runs this independently)
vault operator rekey -nonce=$NONCE <existing-key-share-1>
vault operator rekey -nonce=$NONCE <existing-key-share-2>
vault operator rekey -nonce=$NONCE <existing-key-share-3>

# Step 3: On final share, new keys are returned
# IMMEDIATELY securely distribute new shares to key holders
# IMMEDIATELY shred /tmp/vault-rekey-init.json
shred -u /tmp/vault-rekey-init.json
```

**CRITICAL:** New key shares must be distributed to separate key holders before the terminal session ends. Losing unseal keys = permanent data loss.

---

## Scenario 4: Rotate Istio service mesh certificates

Istio rotates workload certificates automatically every 24 hours. This procedure manually forces rotation.

```bash
# Check current certificate expiry for a pod
istioctl proxy-config secret <pod-name>.<namespace> | grep -A3 "Certificate"

# Force certificate rotation for a specific pod (restart the pod)
kubectl rollout restart rollout/<service> -n <namespace>

# Force Citadel (istiod) to rotate the CA certificate
# (Only needed if CA cert is compromised — rare)
kubectl rollout restart deployment/istiod -n istio-system

# Watch for new certs to be pushed (should complete within 60s)
istioctl proxy-config secret <pod-name>.<namespace>
```

---

## Scenario 5: Rotate Cosign signing key (break-glass key)

The platform uses keyless Cosign signing via GitHub OIDC. There is no long-lived key to rotate.

If a human-held emergency key needs rotation:

```bash
# Generate new Cosign key pair
cosign generate-key-pair

# Store private key in Vault (never in git)
vault kv put secret/platform/cosign-emergency-key \
  private_key=@cosign.key

# Update the Kyverno ClusterPolicy to reference the new key
# Edit platform/security/kyverno-policies.yaml
# Update platform/security/cosign-policy.yaml

# Delete old key from Vault (after policy is updated and deployed)
vault kv delete secret/platform/cosign-emergency-key-old

# Shred local key files
shred -u cosign.key cosign.pub
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| ESO shows `SecretSyncedError: permission denied` | Vault policy not allowing SA | `vault write auth/kubernetes/role/<service> policies=<service>` |
| ESO shows `SecretSyncedError: dial tcp: no route to host` | Vault pod down | `kubectl get pods -n vault` |
| `force-sync` annotation doesn't trigger sync | ESO controller issue | `kubectl rollout restart deploy/external-secrets -n external-secrets` |
| Pod restarts but still uses old secret | Secret not updated in K8s | Check `kubectl get secret -n $NS $SERVICE-secrets -o yaml` |
| Vault sealed after node restart | Vault auto-unseal not configured | `vault operator unseal <key-share>` (3 times) |
