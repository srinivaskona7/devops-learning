# Walkthrough — Install bitnami/nginx with Overrides

End-to-end. Copy/paste each block.

## 1. Add repo & inspect

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm show chart bitnami/nginx
helm show values bitnami/nginx > /tmp/nginx-defaults.yaml
wc -l /tmp/nginx-defaults.yaml   # ~1500 lines — daunting but normal
```

## 2. Create override file

```bash
cat > /tmp/nginx-vals.yaml <<'EOF'
replicaCount: 2

image:
  tag: 1.27.0-debian-12-r0

service:
  type: ClusterIP
  ports:
    http: 80

ingress:
  enabled: true
  hostname: nginx.local
  ingressClassName: nginx

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

metrics:
  enabled: false
EOF
```

## 3. Dry-run preview

```bash
helm install web bitnami/nginx \
  -n web --create-namespace \
  -f /tmp/nginx-vals.yaml \
  --dry-run --debug | less
```

## 4. Real install

```bash
helm install web bitnami/nginx \
  -n web --create-namespace \
  -f /tmp/nginx-vals.yaml \
  --atomic --wait --timeout 5m
```

## 5. Verify

```bash
helm list -n web
helm status web -n web
kubectl get all -n web
kubectl get ingress -n web
```

## 6. Upgrade — bump replicas

```bash
helm upgrade web bitnami/nginx \
  -n web -f /tmp/nginx-vals.yaml \
  --set replicaCount=4 --atomic
helm history web -n web
```

## 7. Rollback

```bash
helm rollback web 1 -n web
helm history web -n web      # revision 3 = revision 1 content
```

## 8. Uninstall

```bash
helm uninstall web -n web
kubectl delete ns web
```

## Key Takeaways

- Pin image tags. Never trust `latest`.
- Always `--dry-run --debug` first on production.
- Use `--atomic` to avoid stuck partial installs.
- Treat values files as code — commit them per environment.
