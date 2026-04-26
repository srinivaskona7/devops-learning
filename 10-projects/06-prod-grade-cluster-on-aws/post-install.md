# Post-Install — ArgoCD + Observability + Smoke Tests

After `terraform apply` finishes, run these in order.

## 1. Configure kubectl

```bash
cd terraform
$(terraform output -raw kubeconfig_command)
kubectl get nodes -o wide
```

## 2. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.4/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=300s

ARGO_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "admin / $ARGO_PW"
```

## 3. Expose ArgoCD via AWS LB (production pattern)

```bash
kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "LoadBalancer"}}'
kubectl -n argocd get svc argocd-server -w
# Once EXTERNAL-IP is set, browse to https://<elb-hostname>
```

## 4. kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --version 62.6.0 \
  --set grafana.adminPassword='admin' \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp3 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --wait --timeout 10m

kubectl -n monitoring get svc kps-grafana
```

## 5. Smoke test — deploy hello-world from Project 01

```bash
kubectl create namespace proj01
kubectl -n proj01 apply -f ../../01-hello-world-end-to-end/k8s/
kubectl -n proj01 rollout status deploy/hello-world
```

## 6. IRSA test

```bash
APP_ROLE=$(terraform output -raw app_s3_role_arn)

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-s3-reader
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${APP_ROLE}
---
apiVersion: v1
kind: Pod
metadata: { name: aws-cli, namespace: default }
spec:
  serviceAccountName: app-s3-reader
  containers:
    - name: aws
      image: amazon/aws-cli:2.17.20
      command: ["sleep","3600"]
EOF

kubectl wait pod/aws-cli --for=condition=Ready --timeout=60s
kubectl exec aws-cli -- aws sts get-caller-identity
# Arn should end with assumed-role/<cluster>-app-s3-reader/...
```

## 7. Persistent volume test

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: test-pvc }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 1Gi } }
EOF

kubectl get pvc test-pvc          # Pending until consumed (WFC binding)

kubectl run pv-tester --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"pv-tester","image":"busybox","command":["sh","-c","echo hi > /data/x; sleep 3600"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"test-pvc"}}]}}'

kubectl get pvc test-pvc          # Bound
kubectl exec pv-tester -- cat /data/x
```

## 8. Cleanup checklist

- [ ] `helm -n monitoring uninstall kps`
- [ ] `kubectl delete ns argocd monitoring proj01 default/aws-cli`
- [ ] `kubectl delete pvc --all -A` (orphaned EBS volumes cost money)
- [ ] `terraform destroy`
- [ ] Verify in AWS console: no leftover ELBs, EBS volumes, NAT gateways
