# Secrets Management — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# External Secrets Operator (ESO)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Sealed Secrets controller (Bitnami)
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# kubeseal CLI
brew install kubeseal   # or curl from GH releases
```

## Apply policies / manifests

```bash
# Create a Secret the wrong way (plaintext, do not commit)
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='hunter2' \
  -n app

# Apply ExternalSecret + ClusterSecretStore (AWS Secrets Manager)
kubectl apply -f external-secret.yaml

# Seal a secret for git
kubectl create secret generic db-creds \
  --from-literal=password=hunter2 \
  --dry-run=client -o yaml \
  | kubeseal --format yaml > db-creds-sealed.yaml
kubectl apply -f db-creds-sealed.yaml
```

## Inspect / verify

```bash
# The base64 trap — proves it is NOT encrypted
kubectl get secret db-creds -n app -o jsonpath='{.data.password}' | base64 -d

# Show the materialised Secret from an ExternalSecret
kubectl get externalsecret -n app
kubectl describe externalsecret db-creds-eso -n app
kubectl get secret db-creds-eso -n app -o yaml

# ESO health
kubectl get clustersecretstore
kubectl logs -n external-secrets deploy/external-secrets

# Audit: who can read secrets in a namespace?
kubectl auth can-i get secrets -n prod --as=alice
kubectl get rolebindings,clusterrolebindings -A -o json \
  | jq '.items[] | select(.roleRef.name | test("admin|edit"))'
```

## Common operations

```bash
# Rotate a secret in AWS — ESO picks up on next refreshInterval
aws secretsmanager put-secret-value \
  --secret-id prod/db-creds \
  --secret-string '{"password":"newpass"}'

# Force ESO refresh now (bump annotation)
kubectl annotate externalsecret db-creds-eso \
  force-sync=$(date +%s) -n app --overwrite

# Mount as file (preferred over env)
# spec.containers[].volumeMounts + spec.volumes[].secret.secretName

# Re-encrypt all existing secrets after enabling etcd EncryptionConfiguration
kubectl get secrets -A -o json | kubectl replace -f -
```

## Cleanup

```bash
kubectl delete externalsecret db-creds-eso -n app
kubectl delete secret db-creds db-creds-eso -n app
kubectl delete clustersecretstore aws-secretsmanager
helm uninstall external-secrets -n external-secrets
helm uninstall sealed-secrets -n kube-system
```

## One-liners worth memorising

```bash
# Decode any Secret field
kubectl get secret <name> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# List every Secret across the cluster (audit scope)
kubectl get secrets -A --field-selector type!=kubernetes.io/service-account-token

# Find pods with secrets in env vars (leak risk)
kubectl get pods -A -o json \
  | jq -r '.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef) | "\(.metadata.namespace)/\(.metadata.name)"'

# Confirm etcd encryption is on (control plane)
sudo grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml
```
