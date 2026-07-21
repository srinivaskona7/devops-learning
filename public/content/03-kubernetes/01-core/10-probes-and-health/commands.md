# Probes & Health — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
```

## Apply manifests

```bash
kubectl apply -f probes-demo.yaml
```

## Inspect / verify

```bash
kubectl get pod probes-demo -w           # readiness flips false → true
kubectl describe pod probes-demo | grep -A3 -E 'Liveness|Readiness|Startup'
kubectl get pod probes-demo -o jsonpath='{.status.containerStatuses[0].ready}'
kubectl get pod probes-demo -o jsonpath='{.status.conditions}' | jq
```

## Force a liveness fail (see restart)

```bash
kubectl exec probes-demo -- rm /tmp/healthy
kubectl get pod probes-demo -w           # RESTARTS goes 0 → 1
kubectl describe pod probes-demo | grep -A5 Events
```

## Inspect probe events

```bash
kubectl get events --field-selector involvedObject.name=probes-demo --sort-by=.lastTimestamp
kubectl logs probes-demo --previous       # previous container logs after restart
```

## Tune fields (in manifest)

| Field | Default | Notes |
|-------|---------|-------|
| `initialDelaySeconds` | 0 | Wait before first probe |
| `periodSeconds` | 10 | How often |
| `timeoutSeconds` | 1 | Probe call timeout |
| `successThreshold` | 1 | Consecutive successes to pass |
| `failureThreshold` | 3 | Consecutive failures to fail |

## Probe handler examples (snippets)

```yaml
# httpGet
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }

# tcpSocket
readinessProbe:
  tcpSocket: { port: 5432 }

# exec
livenessProbe:
  exec: { command: [cat, /tmp/healthy] }

# grpc (K8s 1.24+)
livenessProbe:
  grpc: { port: 9000 }
```

## Cleanup

```bash
kubectl delete -f probes-demo.yaml
```

## One-liners worth memorising

```bash
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].ready}'
kubectl describe pod <pod> | grep -A3 -E 'Liveness|Readiness|Startup'
kubectl logs <pod> --previous
kubectl exec <pod> -- rm /tmp/healthy             # simulate liveness fail
kubectl get events --field-selector involvedObject.name=<pod>
```
