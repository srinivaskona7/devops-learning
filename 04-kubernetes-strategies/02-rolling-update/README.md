# 02 — Rolling Update Strategy

> The Kubernetes default. Replaces pods incrementally with no downtime. Tunable via `maxSurge` and `maxUnavailable`.

## Concept

Kubernetes brings up a few new pods, waits for them to be Ready, then terminates a few old pods — repeating until all replicas are on the new version.

Two knobs control the pace:

| Field | Meaning | Default |
|-------|---------|---------|
| `maxSurge` | Extra pods above desired count during update | 25% |
| `maxUnavailable` | Pods that may be unavailable during update | 25% |

`maxSurge=1, maxUnavailable=0` is the safest config: always at full capacity, one extra pod at a time.

## When to use

- **Default** for any stateless service that can run two versions side by side.
- HTTP APIs, gRPC services, web frontends.

## Drawbacks

- During the rollout, **both versions serve traffic simultaneously** — your code must tolerate that (forward/backward compat for DB, APIs, message formats).
- Rollback means another rolling update — not instant.
- No traffic-percentage control; first new pod gets `replicas / total` share of requests immediately.

## Pod transition (replicas=4, maxSurge=1, maxUnavailable=0)

```mermaid
sequenceDiagram
    participant D as Deployment
    participant V1 as v1 pods
    participant V2 as v2 pods
    participant S as Service
    Note over V1: 4 v1 pods serving
    D->>V2: create 1 v2 pod (surge)
    V2-->>S: ready (now 5 endpoints, mixed)
    D->>V1: terminate 1 v1 pod
    V1-->>S: deregistered (4 endpoints)
    D->>V2: create 1 v2 pod
    V2-->>S: ready (5 endpoints)
    D->>V1: terminate 1 v1 pod
    Note over D,S: ...repeat until all are v2
    Note over V2: 4 v2 pods serving — done
```

## Files

- [`deployment.yaml`](./deployment.yaml) — `RollingUpdate` with `maxSurge=1, maxUnavailable=0`
- [`demo.sh`](./demo.sh)

## Run

```bash
bash demo.sh
```

## Verify

```bash
kubectl rollout status deployment/hello-rolling
kubectl rollout history deployment/hello-rolling
kubectl get pods -L version --watch
```

## Cleanup

```bash
kubectl delete -f deployment.yaml --ignore-not-found
```

> **Gotcha:** Without proper `readinessProbe`, K8s thinks pods are ready the second they start. Bad readiness = users get 503s during rollout. Always define a real probe.

> **Gotcha:** `maxUnavailable=0` requires headroom on your nodes. If the cluster is full, the surge pod can't be scheduled and the rollout stalls.
