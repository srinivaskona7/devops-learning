# Production-Grade Deployment — Commands

> Quick pickup reference. Pair with `README.md` for theory. Composed via Kustomize.

## Setup

```bash
kubectl cluster-info
kubectl get nodes -o wide                     # need >=2 nodes for spread/anti-affinity
```

## Apply manifests

```bash
# Single command — Kustomize composes deployment + svc + pdb + hpa + networkpolicy
kubectl apply -k .

# Or individually
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f pdb.yaml
kubectl apply -f hpa.yaml
kubectl apply -f networkpolicy.yaml
```

## Inspect / verify

```bash
kubectl get all,pdb,hpa,networkpolicy -l app=hello-prod
kubectl describe pdb hello-prod
kubectl describe hpa hello-prod
kubectl describe networkpolicy hello-prod

# Check pods spread across nodes / zones
kubectl get pods -l app=hello-prod -o wide
kubectl get pods -l app=hello-prod \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'
```

## Test PDB protection

```bash
# Drain a node — PDB blocks if disruption would violate it
kubectl drain kind-worker --ignore-daemonsets --delete-emptydir-data
kubectl uncordon kind-worker
```

## Verify securityContext

```bash
kubectl get pod -l app=hello-prod -o jsonpath='{.items[0].spec.securityContext}'
kubectl exec -it -l app=hello-prod -- id          # uid != 0
kubectl exec -it -l app=hello-prod -- touch /test # read-only root FS -> denied
```

## Verify NetworkPolicy

```bash
kubectl get netpol
kubectl describe netpol hello-prod

# From an unauthorized pod — should be blocked
kubectl run test --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s --max-time 3 http://hello-prod/ || echo BLOCKED
```

## Common operations

```bash
# Diff before apply
kubectl diff -k .

# Render Kustomize output without applying
kubectl kustomize .

# Force-rollout (e.g., after secret change)
kubectl rollout restart deployment/hello-prod
```

## Cleanup

```bash
kubectl delete -k .
```

## Production checklist (printable)

- [ ] Resource requests AND limits on every container
- [ ] startup + readiness + liveness probes on different endpoints
- [ ] securityContext: runAsNonRoot, readOnlyRootFilesystem, drop ALL caps
- [ ] Dedicated ServiceAccount, least-privilege RBAC
- [ ] topologySpreadConstraints across zones
- [ ] podAntiAffinity to avoid co-location
- [ ] PodDisruptionBudget set
- [ ] HPA with sensible min/max
- [ ] NetworkPolicy: default deny + explicit allow
- [ ] Image pinned by tag or digest, no `:latest`
- [ ] Cloud workload identity (IRSA / Workload Identity)
- [ ] terminationGracePeriodSeconds + preStop hook
- [ ] Logs to stdout/stderr; Prometheus scrape annotations / ServiceMonitor
- [ ] Stored in Git, applied via Argo CD / Flux

## One-liners worth memorising

```bash
kubectl apply -k .
kubectl diff -k .
kubectl kustomize .
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
kubectl get all,pdb,hpa,networkpolicy -l app=<name>
```
