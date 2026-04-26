# Project 06 (Production-Grade EKS Cluster) — Commands

> Quick pickup reference. Full walkthrough in `README.md` and `post-install.md`.
> COSTS ~$1/hr while running. Run `terraform destroy` when done.

## Prerequisites
```bash
aws sts get-caller-identity       # creds OK
terraform version                 # >= 1.6
kubectl version --client
helm version
```

## Build
```bash
cd 08-projects/06-prod-grade-cluster-on-aws/terraform

terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
```

## Deploy
```bash
# 15-20 min provisioning
terraform apply tfplan

# Wire kubectl
aws eks update-kubeconfig --region us-east-1 \
  --name $(terraform output -raw cluster_name)

kubectl get nodes -o wide

# Post-install: ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.4/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=300s

# Post-install: kube-prometheus-stack on gp3
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
```

## Verify
```bash
# Addons
aws eks list-addons --region us-east-1 \
  --cluster-name $(terraform output -raw cluster_name)

kubectl -n kube-system get pods
kubectl get sc                    # gp3 default

# ArgoCD UI
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
kubectl -n argocd patch svc argocd-server -p '{"spec":{"type":"LoadBalancer"}}'
kubectl -n argocd get svc argocd-server -w

# Grafana ELB
kubectl -n monitoring get svc kps-grafana

# IRSA smoke test (replace ROLE arn from terraform output)
APP_ROLE=$(terraform output -raw app_s3_role_arn)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: { name: app-s3-reader, namespace: default,
  annotations: { eks.amazonaws.com/role-arn: ${APP_ROLE} } }
---
apiVersion: v1
kind: Pod
metadata: { name: aws-cli, namespace: default }
spec:
  serviceAccountName: app-s3-reader
  containers: [{ name: aws, image: amazon/aws-cli:2.17.20, command: ["sleep","3600"] }]
EOF
kubectl wait pod/aws-cli --for=condition=Ready --timeout=60s
kubectl exec aws-cli -- aws sts get-caller-identity
```

## Cleanup
```bash
helm -n monitoring uninstall kps
kubectl delete ns argocd monitoring
kubectl delete pod aws-cli
kubectl delete sa app-s3-reader
kubectl delete pvc --all -A          # orphaned EBS = $$$

cd 08-projects/06-prod-grade-cluster-on-aws/terraform
terraform destroy -auto-approve

# Manual sweep — confirm no leftovers
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes  --region us-east-1 --query 'Volumes[?State==`available`].VolumeId'
aws ec2 describe-nat-gateways --region us-east-1 --query 'NatGateways[?State==`available`].NatGatewayId'
```

## One-liners worth memorising
```bash
# Re-apply only one addon
aws eks update-addon --cluster-name $(terraform output -raw cluster_name) \
  --addon-name vpc-cni --region us-east-1

# Tail control-plane authentication errors
kubectl get events -A --sort-by=.lastTimestamp | tail -20

# Print cluster OIDC issuer (needed for IRSA trust policies)
aws eks describe-cluster --name $(terraform output -raw cluster_name) \
  --query 'cluster.identity.oidc.issuer' --output text

# tf output as env vars
eval "$(terraform output -json | jq -r 'to_entries[] | "export TF_\(.key|ascii_upcase)=\(.value.value)"')"
```
