# Canary with Argo Rollouts — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup — install Argo Rollouts

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# kubectl plugin (macOS)
brew install argoproj/tap/kubectl-argo-rollouts
# or:
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
chmod +x kubectl-argo-rollouts-darwin-amd64
sudo mv kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts
```

## Apply manifests

```bash
kubectl apply -f analysistemplate.yaml
kubectl apply -f rollout.yaml
```

## Inspect / verify

```bash
kubectl get rollout
kubectl argo rollouts get rollout hello-rollout
kubectl argo rollouts get rollout hello-rollout --watch
kubectl argo rollouts dashboard                       # http://localhost:3100
```

## Trigger a release

```bash
kubectl argo rollouts set image hello-rollout \
  hello=gcr.io/google-samples/hello-app:2.0
kubectl argo rollouts get rollout hello-rollout --watch
```

## Promote / abort / retry

```bash
kubectl argo rollouts promote hello-rollout                 # advance past pause
kubectl argo rollouts promote hello-rollout --full          # skip remaining steps
kubectl argo rollouts abort   hello-rollout                 # back to 100% stable
kubectl argo rollouts retry   hello-rollout                 # restart aborted
kubectl argo rollouts undo    hello-rollout                 # rollback
kubectl argo rollouts restart hello-rollout                 # restart pods
```

## Inspect status / weights

```bash
kubectl argo rollouts status hello-rollout
kubectl get rollout hello-rollout \
  -o jsonpath='{.status.currentStepIndex}/{.status.canary.weights.canary.weight}'; echo

# AnalysisRuns
kubectl get analysisrun
kubectl describe analysisrun <name>
```

## Pause / resume

```bash
kubectl argo rollouts pause hello-rollout
kubectl argo rollouts promote hello-rollout
```

## Cleanup

```bash
kubectl delete -f rollout.yaml -f analysistemplate.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl argo rollouts set image <ro> <c>=<image>:<tag>
kubectl argo rollouts get rollout <ro> --watch
kubectl argo rollouts promote <ro>
kubectl argo rollouts abort <ro>
kubectl argo rollouts dashboard
kubectl get analysisrun
```
