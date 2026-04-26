# Controller Reconcile Loop

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-01-crds-and-operators-controller-pattern-1-c682ec48.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-01-crds-and-operators-controller-pattern-1-c682ec48.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-01-crds-and-operators-controller-pattern-1-c682ec48.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant User
    participant API as kube-apiserver
    participant Inf as Informer (cache)
    participant Q as Workqueue
    participant R as Reconciler
    participant Ext as External system

    User->>API: kubectl apply foo.yaml
    API->>Inf: watch event (ADD)
    Inf->>Q: enqueue key ns/name
    Q->>R: dequeue
    R->>Inf: Get(Foo) from cache
    R->>Ext: read actual state
    alt drift detected
      R->>API: Create/Update child resources
      R->>API: Update status subresource
    else converged
      R->>R: no-op
    end
    R->>Q: requeue after N (or on next event)
```

</details>

</details>

</details>

## Rules
- **Idempotent**: same input -> same action, safe to retry.
- **Level-triggered**, not edge-triggered: always reconcile from current state, never from the event payload.
- **Status vs Spec**: write status only via the `/status` subresource to avoid optimistic-lock churn.
- **Finalizers**: add a finalizer string in `metadata.finalizers` to defer deletion until cleanup completes; remove it when done.
- **Owner references**: set `ownerReferences` on child objects so they GC when the parent is deleted.
- **Backoff**: use rate-limited workqueues (controller-runtime does this by default).

## Common traps
- Mutating cached objects from the informer — always `DeepCopy()` first.
- Long-running work in Reconcile — return early and requeue instead.
- Forgetting to handle "not found" (object deleted) — return nil, do not error.
