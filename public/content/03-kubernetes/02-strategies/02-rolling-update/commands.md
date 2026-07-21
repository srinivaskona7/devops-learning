# Rolling Update — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/hello-rolling
```

## Inspect / verify

```bash
kubectl get deploy hello-rolling -o jsonpath='{.spec.strategy}'; echo
kubectl get pods -L version --watch
kubectl rollout history deployment/hello-rolling
```

## Run the demo

```bash
bash demo.sh
```

## Trigger a rolling update

```bash
kubectl set image deployment/hello-rolling hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout status deployment/hello-rolling --watch
kubectl get rs -l app=hello-rolling                   # old + new ReplicaSets
```

## Tune the pace (edit manifest or patch)

```bash
kubectl patch deployment hello-rolling -p '{
  "spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}
}'
```

## Pause / resume

```bash
kubectl rollout pause  deployment/hello-rolling
kubectl set env       deployment/hello-rolling FOO=bar
kubectl set image     deployment/hello-rolling hello=gcr.io/google-samples/hello-app:2.0
kubectl rollout resume deployment/hello-rolling
```

## Continuous probe during rollout

```bash
while true; do
  curl -s --max-time 1 http://hello-rolling/ | head -1
  sleep 0.2
done
```

## Rollback

```bash
kubectl rollout undo deployment/hello-rolling
kubectl rollout undo deployment/hello-rolling --to-revision=1
```

## Cleanup

```bash
kubectl delete -f deployment.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl set image deployment/<name> <c>=<image>:<tag>
kubectl rollout status deployment/<name> --watch
kubectl rollout history deployment/<name>
kubectl rollout pause deployment/<name>
kubectl rollout resume deployment/<name>
kubectl rollout undo deployment/<name>
kubectl get rs -l app=<name>
```
