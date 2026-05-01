# Rollback Patterns — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Run the demo

```bash
bash demo.sh
```

## Inspect revision history

```bash
kubectl rollout history deployment/hello-rollback
kubectl rollout history deployment/hello-rollback --revision=1
kubectl rollout history deployment/hello-rollback --revision=2
kubectl get rs -l app=hello-rollback
kubectl describe deployment hello-rollback | grep -i image
```

## Roll back

```bash
# To previous revision
kubectl rollout undo deployment/hello-rollback

# To a specific revision
kubectl rollout undo deployment/hello-rollback --to-revision=1
```

## Pause / resume

```bash
kubectl rollout pause  deployment/hello-rollback
kubectl set image deployment/hello-rollback hello=gcr.io/google-samples/hello-app:2.0
kubectl set env deployment/hello-rollback FOO=bar
kubectl rollout resume deployment/hello-rollback
```

## Restart (no template change)

```bash
kubectl rollout restart deployment/hello-rollback
```

## Tune retention

```bash
# Default is 10 — never set to 0 (no rollback possible)
kubectl patch deployment hello-rollback -p '{"spec":{"revisionHistoryLimit":5}}'
```

## Image digest pinning (immutable)

```bash
kubectl set image deployment/<name> <c>=gcr.io/google-samples/hello-app@sha256:<digest>
```

## GitOps style rollback (Argo CD / Flux)

```bash
# Argo CD
argocd app rollback <app> <revision>
argocd app history <app>

# Flux
flux suspend kustomization <name>
git revert <commit> && git push
flux resume kustomization <name>
```

## Cleanup

```bash
kubectl delete deployment hello-rollback svc hello-rollback --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=N
kubectl rollout pause deployment/<name>
kubectl rollout resume deployment/<name>
kubectl rollout restart deployment/<name>
kubectl get rs -l app=<name>
```
