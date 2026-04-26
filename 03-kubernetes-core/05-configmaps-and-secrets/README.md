# 05 — ConfigMaps & Secrets

> **ConfigMaps** = non-sensitive config (URLs, feature flags). **Secrets** = sensitive (API keys, passwords). Both decouple config from container images.

## Why decouple

Hardcoded config = rebuild image for every env change. ConfigMaps + Secrets let the same image run anywhere.

```mermaid
flowchart LR
  IMG[Container image<br/>same in dev/staging/prod] --> POD[Pod]
  CM[ConfigMap<br/>per-env config] -->|env var or file| POD
  SEC[Secret<br/>per-env credentials] -->|env var or file| POD
```

## How they're consumed

| Method | Pros | Cons |
|--------|------|------|
| **env var** | simple | no live updates; visible in `ps`/`env` dump |
| **volume mount (file)** | live updates (~60s); not in env | file I/O |
| **subPath mount** | mount one key as a file | no live updates |
| **envFrom** | bulk-load all keys as env | name collisions |

## Secret types

| Type | Use |
|------|-----|
| `Opaque` (default) | arbitrary key/value |
| `kubernetes.io/dockerconfigjson` | private image registry pull |
| `kubernetes.io/tls` | TLS cert + key (Ingress) |
| `kubernetes.io/service-account-token` | auto-mounted SA tokens |

## Apply & observe

```bash
kubectl apply -f configmap.yaml -f secret.yaml -f pod-with-config.yaml
kubectl get cm,secret
kubectl describe pod app-with-config

# Verify config is in the pod
kubectl exec app-with-config -- env | grep -E 'APP_|DB_'
kubectl exec app-with-config -- cat /etc/config/app.properties
kubectl exec app-with-config -- cat /etc/secrets/db-password
```

## Decode a Secret

```bash
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
```

## Immutable ConfigMaps / Secrets

Add `immutable: true` to lock data once created — improves API server perf at scale and prevents accidental edits. Trade-off: must delete + recreate to change.

## Cleanup

```bash
kubectl delete -f configmap.yaml -f secret.yaml -f pod-with-config.yaml
```

## Gotchas

> ⚠️ **Secrets are base64-encoded, NOT encrypted.** Anyone with `get secrets` RBAC sees them in plaintext. Use [Sealed Secrets](https://sealed-secrets.netlify.app/), [External Secrets Operator](https://external-secrets.io/), or [SOPS](https://github.com/getsops/sops) for git-safe storage.

> ⚠️ **Env vars don't auto-update** when ConfigMap changes — pod must restart. Volume mounts DO update (with ~kubelet sync period delay).

> ⚠️ **`stringData` is write-only.** It's auto-converted to base64 in `data`. Don't expect to read it back via `kubectl get -o yaml`.

> ⚠️ Enable [encryption at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) for etcd in production.

## Reference

- [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
