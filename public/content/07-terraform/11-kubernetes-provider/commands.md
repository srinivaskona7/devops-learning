# Kubernetes & Helm Providers — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 11-kubernetes-provider

# Spin up a quick local cluster (no cloud cost)
kind create cluster --name tf-demo
# or: minikube start --driver=docker
# or: k3d cluster create tf-demo

# Confirm kubectl is pointing at the right cluster
kubectl config current-context
kubectl cluster-info
```

## Init / plan / apply

```bash
terraform init                    # downloads kubernetes + helm providers
terraform plan
terraform apply -auto-approve

# Re-apply just one resource
terraform apply -target=kubernetes_namespace.monitoring
terraform apply -target=helm_release.prometheus

# Increase Helm timeout if charts are slow
terraform apply -var="helm_timeout=900"
```

## State operations

```bash
terraform state list
terraform state show kubernetes_namespace.monitoring
terraform state show helm_release.prometheus

# Import an existing namespace
terraform import kubernetes_namespace.monitoring monitoring

# Import an existing Helm release
terraform import helm_release.prometheus monitoring/prometheus
```

## Inspect / verify

```bash
terraform output namespace
terraform output release_status

# Cluster-side verification
kubectl get ns
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get all -n monitoring

# Helm-side verification
helm list -n monitoring
helm status prometheus -n monitoring
helm get values prometheus -n monitoring

# Port-forward Grafana to test locally
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80 &
open http://localhost:3000        # macOS
```

## Cleanup (destroy)

```bash
terraform destroy -auto-approve

# Confirm nothing left behind
kubectl get ns monitoring
helm list -A

# Tear down the local cluster
kind delete cluster --name tf-demo
# or: minikube delete
# or: k3d cluster delete tf-demo

rm -rf .terraform terraform.tfstate*
```

## One-liners worth memorising

```bash
# Switch kube context before running anything
kubectl config use-context kind-tf-demo && terraform plan

# Force a Helm release upgrade in place
terraform apply -replace=helm_release.prometheus

# Render a chart locally without applying (debug values)
helm template prometheus prometheus-community/kube-prometheus-stack \
  --version 65.1.1 -n monitoring | head -50

# Pin chart version in HCL — never let "latest" sneak in
# helm_release.prometheus { version = "65.1.1" ... }

# Quick smoke test of the provider against current context
terraform console <<<'data.kubernetes_namespaces.all'
```
