# Sealed Secrets

[Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) lets you commit encrypted secrets to git. The controller in the cluster holds the private key; only it can decrypt.

## Install

```bash
# Controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# CLI (kubeseal)
brew install kubeseal           # mac
# or download from GitHub releases for linux
```

## Workflow

```bash
# 1. Create a regular secret manifest (DO NOT apply it)
kubectl create secret generic db-creds \
  --from-literal=password='hunter2' \
  --dry-run=client -o yaml > db-creds.yaml

# 2. Encrypt it. Output is a SealedSecret CR — safe to commit.
kubeseal --format yaml --controller-namespace kube-system < db-creds.yaml > db-creds.sealed.yaml

# 3. Apply to cluster (or commit and let ArgoCD sync)
kubectl apply -f db-creds.sealed.yaml

# 4. Verify
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
```

## Scopes

```bash
# strict (default): only decryptable in the same namespace + name
kubeseal --scope strict ...

# namespace-wide: any name in the same namespace
kubeseal --scope namespace-wide ...

# cluster-wide: any namespace, any name
kubeseal --scope cluster-wide ...
```

Use `strict` unless you have a strong reason — looser scopes weaken the model.

## Key rotation

```bash
# Generate a new key (controller does this every 30d by default)
kubectl -n kube-system create secret tls sealed-secrets-keyXXXX \
  --cert=cert.pem --key=key.pem
kubectl -n kube-system label secret sealed-secrets-keyXXXX \
  sealedsecrets.bitnami.com/sealed-secrets-key=active

# Restart controller to pick up
kubectl -n kube-system rollout restart deploy/sealed-secrets

# Old SealedSecrets remain decryptable until you re-seal them
```

## Backup the key

If you lose the master key, **every SealedSecret in git is bricked**. Back it up:

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-master.key
# Store in offline vault. Treat like CA root.
```

## When NOT to use sealed-secrets

- You already run Vault / AWS SM — use ESO instead, you get rotation for free
- Multi-cluster deployments where re-sealing per cluster is painful
- Compliance requirements that mandate external KMS-backed secrets
