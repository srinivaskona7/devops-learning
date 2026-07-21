# ArgoCD Install — Detailed

## Option A: Plain manifests (quickstart)

```bash
ARGOCD_VERSION=v2.12.4
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
```

## Option B: Helm (recommended for prod)

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=false \
  --version 7.6.12
```

## Initial credentials

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

User: `admin`. **Rotate immediately** after first login (Account → Update Password) and delete the bootstrap secret:

```bash
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## CLI install

```bash
brew install argocd            # macOS
# or: curl -sSL -o /usr/local/bin/argocd \
#   https://github.com/argoproj/argo-cd/releases/download/v2.12.4/argocd-linux-amd64

argocd login localhost:8080 --username admin --insecure
argocd cluster list
```

## Expose via Ingress (optional)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

## RBAC (multi-tenant)

```yaml
# argocd-rbac-cm.yaml — patch into argocd-rbac-cm
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:dev, applications, sync, */*, allow
    g, dev-team, role:dev
```

## Common pitfalls
- **Sync stuck on `OutOfSync`**: check `argocd app diff <app>` — usually CRD ordering or webhook timing.
- **TLS cert errors**: ArgoCD ships self-signed; add `--insecure` to CLI or terminate TLS at ingress.
- **App not appearing**: confirm the `Application` lives in the `argocd` namespace (not the target namespace).
