# Canary (Manual) — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f deployment-stable.yaml          # 9 replicas of v1
kubectl apply -f deployment-canary.yaml          # 1 replica of v2
kubectl apply -f service.yaml                    # selector covers BOTH
kubectl rollout status deployment/hello-stable
kubectl rollout status deployment/hello-canary
```

## Inspect / verify

```bash
kubectl get deploy -l app=hello-canary-app
kubectl get endpoints hello-canary-app           # 10 IPs (9 stable + 1 canary)
kubectl get pods -L track,version -o wide
```

## Run the demo

```bash
bash demo.sh
```

## Send traffic and measure split

```bash
for i in $(seq 1 100); do
  kubectl run probe-$i --rm --image=curlimages/curl --restart=Never -- \
    curl -s http://hello-canary-app/ 2>/dev/null
done | sort | uniq -c
```

Or from inside the cluster, single pod:

```bash
kubectl run probe --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'for i in $(seq 1 100); do curl -s http://hello-canary-app/; done' \
  | sort | uniq -c
```

## Promote canary (10 → 100%)

```bash
kubectl scale deployment/hello-canary --replicas=10
kubectl scale deployment/hello-stable --replicas=0
```

## Abort canary (back to 100% stable)

```bash
kubectl scale deployment/hello-canary --replicas=0
```

## Adjust ratio mid-flight

```bash
kubectl scale deployment/hello-canary --replicas=3      # ~30%
kubectl scale deployment/hello-stable --replicas=7
```

## Cleanup

```bash
kubectl delete -f deployment-stable.yaml -f deployment-canary.yaml -f service.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl scale deploy/<canary> --replicas=N
kubectl scale deploy/<stable> --replicas=M
kubectl get endpoints <svc>
kubectl get pods -L track,version
```
