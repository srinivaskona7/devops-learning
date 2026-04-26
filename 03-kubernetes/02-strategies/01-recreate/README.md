# 01 — Recreate Strategy

> Kill all old pods, then start new pods. Causes downtime. Use only when versions cannot co-exist.

## Concept

The `Recreate` strategy is the simplest possible release pattern:

1. Scale all old pods to zero.
2. Wait for them to terminate.
3. Create new pods with the new image.

There is a window (seconds to minutes depending on startup time) where **no pods are serving traffic**. The Service has no endpoints; clients get connection refused / 503.

## When to use

- Local / dev clusters where downtime is irrelevant.
- Batch jobs / cron workloads.
- Schema migrations or stateful workloads where v1 and v2 **must not** co-exist (e.g. exclusive file locks, shared DB locks, conflicting protocol versions).
- Single-replica apps that can't run two pods anyway.

## Drawbacks

- **Downtime is guaranteed.** Don't use for user-facing services in prod.
- No graceful traffic shift; full blast radius.
- No automatic rollback — if v2 is broken you have downtime *and* a broken app.

## Pod transition

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-01-recreate-README-1-6c35dbf7.svg" alt="diagram" / loading="lazy"></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant K as kubectl
    participant D as Deployment
    participant V1 as Pod v1 (x3)
    participant V2 as Pod v2 (x3)
    participant S as Service
    K->>D: apply image:2.0
    D->>V1: terminate all
    Note over S,V1: Service has 0 endpoints — DOWNTIME
    V1-->>D: terminated
    D->>V2: create all
    V2-->>S: ready, registered
    Note over S,V2: Traffic resumes on v2
```

</details>
## Files

- [`deployment.yaml`](./deployment.yaml) — annotated Deployment with `strategy.type: Recreate`
- [`demo.sh`](./demo.sh) — end-to-end demo with continuous curl

## Run

```bash
bash demo.sh
```

## Verify

```bash
kubectl rollout status deployment/hello-recreate
kubectl get pods -L version --watch
```

## Cleanup

```bash
kubectl delete -f deployment.yaml --ignore-not-found
kubectl delete svc hello-recreate --ignore-not-found
```

> **Gotcha:** `Recreate` ignores `maxSurge` / `maxUnavailable`. If your `terminationGracePeriodSeconds` is high, downtime is high. Tune readiness/liveness probes to fail fast.
