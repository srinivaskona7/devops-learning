# Installing Argo Rollouts

## Controller

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n argo-rollouts rollout status deploy/argo-rollouts
```

## kubectl plugin (required for the demo commands)

macOS:
```bash
brew install argoproj/tap/kubectl-argo-rollouts
```

Linux:
```bash
curl -L -o kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts
sudo mv kubectl-argo-rollouts /usr/local/bin/
```

## Verify

```bash
kubectl argo rollouts version
kubectl get crd rollouts.argoproj.io
```

## Optional: Dashboard

```bash
kubectl argo rollouts dashboard
# open http://localhost:3100
```

## Optional: Prometheus (for AnalysisTemplate)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prom prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

The AnalysisTemplate references `prometheus.monitoring:9090` — adjust to match your install.
