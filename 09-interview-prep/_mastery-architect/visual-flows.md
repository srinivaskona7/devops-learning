# Visual Flows — 12 Mermaid Diagrams

Whiteboard-ready diagrams for core distributed-system patterns. Redraw 3 from memory before any system design interview.

---

## 1. Multi-Region Edge → App → DB Request Flow

User requests routed to nearest region; cross-region only on home-region miss.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-1-d8fcbbd8.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[User] --> DNS[GeoDNS]
  DNS --> E[Edge POP]
  E --> APP[Regional App]
  APP --> DB[Regional DB]
  DB --> X[Cross-region async replicate]
```

</details>

**Notes:** Edge terminates TLS. App reads local DB. Writes either go to home region or replicate via async stream. RTT user-to-edge < 50ms, edge-to-app < 10ms.

---

## 2. Retry With Exponential Backoff and Jitter

Failed requests are retried with growing delays plus random jitter to avoid thundering herds.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-2-629e542e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  C[Client] --> T1[Try 1]
  T1 -->|fail| W1[Wait 1s + jitter]
  W1 --> T2[Try 2]
  T2 -->|fail| W2[Wait 2s + jitter]
  W2 --> T3[Try 3]
  T3 -->|ok| OK[Done]
```

</details>

**Notes:** Cap at max retries (5) and max delay (30s). Jitter = random 0..backoff. Without jitter, all clients retry in lockstep and re-DDoS the dependency.

---

## 3. Saga (Compensation-Based Transaction)

Distributed transaction without 2PC: each step has a compensating action on failure.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-3-08887765.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  S[Order placed] --> R[Reserve inventory]
  R --> C[Charge card]
  C --> SH[Ship]
  SH --> D[Done]
  C -->|fail| RR[Release inventory]
```

</details>

**Notes:** Compensations must be idempotent. State machine tracks step. Saga orchestrator coordinates; alternative is choreography (each service emits events).

---

## 4. CQRS (Command Query Responsibility Segregation)

Writes go through commands; reads served from optimized read models.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-4-14ac6c4e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[User] --> CMD[Command API]
  CMD --> WDB[Write DB]
  WDB --> EV[Event stream]
  EV --> RM[Read Model]
  U --> Q[Query API reads RM]
```

</details>

**Notes:** Read model can denormalize, materialize, or join. Eventual consistency between command and query. Used heavily with event sourcing.

---

## 5. Event Sourcing

Store every state change as an append-only event log; rebuild state by replay.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-5-ac622b9c.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  C[Command] --> A[Aggregate]
  A --> E[Append event]
  E --> ES[Event Store]
  ES --> P[Projection]
  P --> RM[Read Models]
```

</details>

**Notes:** Snapshots speed up replay for hot aggregates. Versioning events is forever-painful — design event schemas carefully. Audit log free.

---

## 6. Rate Limiting (Token Bucket)

Each client has a bucket of tokens; each request consumes one; bucket refills at fixed rate.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-6-3642976e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  R[Request] --> B[Token Bucket]
  B -->|has token| API[Forward to API]
  B -->|empty| RJ[429 Too Many]
  TR[Refill timer] --> B
```

</details>

**Notes:** Bucket size = burst tolerance. Refill rate = sustained limit. Distributed implementations use Redis with Lua scripts for atomicity.

---

## 7. Bulkhead (Resource Isolation)

Partition resources so one slow dependency cannot exhaust all threads/connections.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-7-fc7967c7.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  APP[App] --> B1[Pool A 20 threads]
  APP --> B2[Pool B 20 threads]
  APP --> B3[Pool C 20 threads]
  B1 --> SA[Service A slow]
  B2 --> SB[Service B ok]
  B3 --> SC[Service C ok]
```

</details>

**Notes:** A's slowness only saturates pool A. B and C keep serving. Without bulkheads, all 60 threads block on A. Hystrix/Resilience4j patterns.

---

## 8. Cache Stampede Prevention

When a hot key expires, only one fetch goes to the DB; others wait.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-8-7d41f361.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  R[Many requests] --> C[Cache check]
  C -->|hit| OK[Return]
  C -->|miss| L[Lock single fetcher]
  L --> DB[DB fetch]
  DB --> ST[Store + unlock]
  ST --> OK
```

</details>

**Notes:** Use distributed lock (Redis SETNX) or "request coalescing" / singleflight pattern. Alternative: probabilistic early refresh before TTL expires.

---

## 9. Pub/Sub Fan-Out

One event published; many independent consumers process it asynchronously.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-9-933d0627.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  P[Producer] --> T[Topic]
  T --> S1[Email service]
  T --> S2[Analytics]
  T --> S3[Audit log]
  T --> S4[Search index]
```

</details>

**Notes:** Each consumer has own offset; failures isolated. Add new consumers without touching producer. Backpressure handled per consumer queue.

---

## 10. Circuit Breaker State Machine

Three states: closed (normal), open (failing fast), half-open (probing recovery).

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-10-d0b8a461.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  CL[Closed] -->|N failures| OP[Open]
  OP -->|cooldown| HO[Half-Open]
  HO -->|success| CL
  HO -->|fail| OP
```

</details>

**Notes:** Closed = pass-through. Open = reject immediately, no call. Half-open = let one through to test. Failure threshold tunable per dependency.

---

## 11. Read-Through Cache

App always reads from cache; cache pulls from DB on miss.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-11-a8c06305.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  A[App] --> C[Cache]
  C -->|hit| R[Return]
  C -->|miss| DB[Fetch DB]
  DB --> CW[Cache write]
  CW --> R
```

</details>

**Notes:** Simpler than cache-aside (app handles miss). Variants: write-through (DB on write), write-behind (async DB write). TTL or LRU eviction.

---

## 12. Outbox Pattern (Reliable Event Publishing)

Write business state and event in same transaction; relay publishes events from outbox.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-12-f96abbad.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  TX[Transaction] --> ST[State update]
  TX --> OB[Outbox row]
  OB --> RL[Relay process]
  RL --> K[Kafka]
  RL --> M[Mark sent]
```

</details>

**Notes:** Solves dual-write problem (DB + Kafka can't be atomic). Relay is at-least-once → consumers must be idempotent. Debezium CDC is a common relay.

---

## Pattern Selection Cheatsheet

| Need | Pattern |
|------|---------|
| Cross-service transaction | Saga |
| Reliable event publish | Outbox |
| Slow dependency isolation | Bulkhead |
| Failing dependency | Circuit Breaker |
| Read scale | Cache + Read Replicas |
| Write scale | Sharding + CQRS |
| Audit trail / replay | Event Sourcing |
| Spike protection | Rate Limit + Backpressure |
| Burst smoothing | Queue |
| Latency to global users | CDN + Multi-Region |

---

## Composite Flow — End-to-End Order

How patterns compose for a real user order. (Simplified to 6 nodes.)

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-13-9cc3a8dc.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[User] --> EDGE[Edge + Rate limit]
  EDGE --> API[API Gateway]
  API --> SAGA[Saga orchestrator]
  SAGA --> Q[Outbox - Kafka]
  Q --> DS[Downstream services]
```

</details>

---

## Failure-Mode Drawing

When asked "what happens if X breaks?", draw the X with a red mark and trace the impact.

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/09-interview-prep-_mastery-architect-visual-flows-14-d45604f2.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  C[Client] --> LB[LB ok]
  LB --> S1[Server1 ok]
  LB --> S2[Server2 dead]
  S1 --> DB[DB ok]
  LB -.skip dead.-> S2
```

</details>

**Drawing rules:**
- Use `dead`, `slow`, `partition` labels on nodes.
- Draw the affected request path; what does the user experience?
- Then draw the recovery path: health check fails, LB removes, traffic shifts.

---

## Tips for Whiteboard Sessions

1. Always start with one box for the user, one for the system. Then expand.
2. Label arrows with protocol + sync/async (e.g. "HTTP sync", "Kafka async").
3. Mark fault domains explicitly (AZ1, AZ2, region boundaries).
4. After happy path, ask interviewer "want me to draw failure modes?"
5. Keep diagrams to ≤ 6 nodes per view; use sub-diagrams for depth.
6. Use the same node names across diagrams so the audience tracks state.
