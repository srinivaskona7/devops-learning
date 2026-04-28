# Visual Flows — 8 Mermaid Diagrams of Strategies in Motion

Each diagram shows a strategy at a specific moment of the rollout: pods
being replaced, services flipping, traffic shifting. Read top to bottom —
each diagram is a "snapshot" of one phase.

---

## Flow 1 — Rolling Update: pod-by-pod replacement

A 4-pod Deployment swapping v1 to v2 with maxSurge 1, maxUnavailable 0.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-1-dba78039.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Start[Start: 4x v1] --> S1["Add 1x v2<br/>now 5 pods"]
  S1 --> S2["Kill 1x v1<br/>now 4 pods"]
  S2 --> S3["Add 1x v2<br/>now 5 pods"]
  S3 --> S4["Kill 1x v1<br/>continue"]
  S4 --> Done[End: 4x v2]
```

</details>

**What is moving:** ReplicaSet count. Old RS scales down, new RS scales up,
in lockstep, controlled by surge / unavailable settings.

---

## Flow 2 — Blue/Green: Service selector flip

Two ReplicaSets exist simultaneously. The Service points to one at a time.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-2-93065f83.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[Users] --> Svc["Service<br/>selector: blue"]
  Svc --> B["Blue RS v1<br/>4 pods"]
  G["Green RS v2<br/>4 pods"] -.idle.-> Wait[Pre-warm]
  Wait --> Flip[Patch selector to green]
  Flip --> Done[Service now routes to Green]
```

</details>

**What is moving:** A label-selector edit on the Service. Pod count stays
constant; only the routing flips. Rollback = flip the label back.

---

## Flow 3 — Canary: progressive traffic shift

Argo Rollouts moving traffic 0 -> 10 -> 50 -> 100.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-3-f88fcb49.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Start["100 percent stable<br/>0 percent canary"] --> Step1[90 / 10]
  Step1 --> Analyse1["AnalysisRun<br/>checks SLIs"]
  Analyse1 --> Step2[50 / 50]
  Step2 --> Analyse2["AnalysisRun<br/>checks SLIs"]
  Analyse2 --> Done[0 / 100]
```

</details>

**What is moving:** Weights in the TrafficRouting resource (Istio
VirtualService, SMI TrafficSplit, or NGINX canary annotation). Pods stay
running on both sides until promotion completes.

---

## Flow 4 — Shadow / Mirror: traffic copied, responses discarded

Real users hit stable. A copy of each request goes to shadow.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-4-bf14ef4b.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[User Request] --> Mesh[Sidecar Proxy]
  Mesh --> Stable["Stable v1<br/>responds to user"]
  Mesh -.mirror copy.-> Shadow["Shadow v2<br/>processes silently"]
  Shadow --> Drop[Response dropped]
  Stable --> User2[User receives]
```

</details>

**What is moving:** A `mirror` directive in the VirtualService. The proxy
duplicates the request; only the original path returns to the user.

---

## Flow 5 — A/B Testing: header-based routing

Routes are decided per-request based on a header value.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-5-520c463e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  U[Request] --> GW[Gateway]
  GW --> Match{Header<br/>x-experiment?}
  Match -->|group-a| A[Variant A]
  Match -->|group-b| B[Variant B]
  Match -->|none| Default[Default Stable]
```

</details>

**What is moving:** Nothing on the cluster after setup. The router
evaluates each request and picks a destination subset based on rules.
Experiments are observed via downstream analytics.

---

## Flow 6 — Multi-cluster Blue/Green: global LB flip

Two full clusters. A global load balancer steers traffic.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-6-b614bf6a.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Users[Global Users] --> GLB[Global Load Balancer]
  GLB -->|100 percent| C1["Cluster Blue<br/>region us-east"]
  GLB -.0 percent.-> C2["Cluster Green<br/>region us-west"]
  Flip[Update GLB weights] --> GLB
  C2 --> Ready[Pre-validated via synthetics]
```

</details>

**What is moving:** GLB backend weights (or weighted DNS records). A single
config change at the edge swings all global traffic between clusters.

---

## Flow 7 — Canary with SLO gate (auto-abort path)

Argo Rollouts AnalysisRun fails — rollout reverses.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-7-a0f054ac.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Step[Step 3: 50 percent] --> Analyse["AnalysisRun<br/>queries Prometheus"]
  Analyse --> Decision{p99 latency OK?<br/>error rate OK?}
  Decision -->|Pass| Promote[Promote to 100 percent]
  Decision -->|Fail| Abort[Abort: shift back to stable]
  Abort --> Stable[100 percent stable v1]
```

</details>

**What is moving:** The AnalysisRun executes metric queries. On failure,
Argo flips traffic back to stable and scales the canary RS down. On
success, it advances to the next step in the strategy spec.

---

## Flow 8 — Rolling Update with PDB and HPA interactions

Real-world rolling: probes, PDB, and HPA all engage simultaneously.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-8-0108886f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart TB
  Trigger[kubectl set image] --> RS[New ReplicaSet created]
  RS --> Surge[maxSurge pod started]
  Surge --> Probe[readinessProbe wait]
  Probe --> PDB{PDB allows<br/>termination?}
  PDB -->|Yes| Kill[Old pod terminated]
  PDB -->|No| Wait[Block until safe]
```

</details>

**What is moving:** ReplicaSet controller, kubelet probes, PDB controller,
and optionally HPA all coordinate. The PDB acts as a brake — if too few
pods would remain ready, the rollout pauses until availability returns.

---

## Bonus: lifecycle of a single pod during rolling update

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-9-550e6935.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Pending[Pending] --> Init[Init containers]
  Init --> Start[Container start]
  Start --> Startup[startupProbe]
  Startup --> Ready["readinessProbe<br/>passes"]
  Ready --> Serve[Receives traffic]
```

</details>

**What is moving:** Pod phase transitions. A new pod is "Ready" only after
all probes pass; only then does the Service endpoint controller add it to
the active pool. Old pods enter `Terminating` phase, drained via
preStop hook + terminationGracePeriodSeconds.

---

## Flow comparison: traffic shape over time

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-10-61863058.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  R["Rolling: gradual<br/>pod swap"] --> O1["Mixed v1 plus v2<br/>during window"]
  B["Blue Green: instant<br/>flip"] --> O2["100 percent v1 then<br/>100 percent v2"]
  C["Canary: stepped<br/>weights"] --> O3["1 then 10 then 50<br/>then 100 percent v2"]
```

</details>

---

## Reading the diagrams

- Solid arrow = active traffic or state transition.
- Dotted arrow = mirror, idle, or alternate path.
- Diamond = decision gate (probe, analysis, PDB).
- Rectangle = pod, RS, Service, or controller action.

---

## How to extend these for your team

1. Replace generic labels with your service names.
2. Add observability hooks (Prometheus targets, Datadog tags).
3. Annotate each transition with the kubectl / argo command that triggers it.
4. Render in Backstage or your wiki for onboarding.

---

## Cross-references

- For the "why" behind each flow: see `architect-qa.md`.
- For analogies: see `eli10.md`.
- For real manifests: see `02-strategies/` examples folder.

---

## Flow 9 — Argo Rollouts BlueGreen with preview Service

A second Service (the preview Service) lets you test green before flipping
the active Service.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-11-cb855ba4.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Active[Active Service] --> Blue[Blue v1 Pods]
  Preview[Preview Service] --> Green[Green v2 Pods]
  Tester[QA + synthetics] --> Preview
  Promote[Promote command] --> Flip[Active points to Green]
```

</details>

**What is moving:** Two Services with different selectors. The Rollout
controller swaps both selectors when promoted. The preview Service is the
secret weapon — full smoke testing on green before any user is touched.

---

## Flow 10 — Flagger canary with automatic rollback

Flagger watches metrics each interval and auto-aborts on breach.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-12-0ee6222a.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Start[Canary deployed] --> Step[Increase 10 percent]
  Step --> Metric[Query Prometheus]
  Metric --> Gate{Threshold OK?}
  Gate -->|Yes| Next[Next step]
  Gate -->|No| Rollback[Auto rollback to primary]
```

</details>

---

## Flow 11 — Database-backward-compat dance

The danger zone — schema must serve both versions during the rollout.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-13-bab83921.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  V1[App v1 reads col_a] --> DB["Database<br/>col_a + col_b"]
  V2[App v2 reads col_b] --> DB
  DB --> Both[Both versions happy]
  Cleanup[Drop col_a after v1 gone] --> DB
```

</details>

**What is moving:** Two-phase migration. Add new column, deploy code that
writes both, deploy code that reads new, then drop old. Never combine
schema change with code change in one rollout.

---

## Flow 12 — Argo Rollouts experiment (sidecar canary for analysis)

An Experiment runs a temporary canary purely for measurement, separate
from the user-facing rollout.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-02-strategies-_mastery-visual-flows-14-b1c70936.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  Stable[Stable RS] --> Users[Users]
  Exp[Experiment RS] --> Synth[Synthetic load]
  Synth --> Metric[Compare metrics]
  Metric --> Verdict{Pass?}
  Verdict -->|Yes| Promote[Allow real rollout]
```

</details>

---

## Reading-the-code map

When you open a Rollout manifest, here is which YAML field maps to which
visual element above:

| YAML field | Visual element |
|------------|----------------|
| `strategy.canary.steps` | Flow 3 traffic shift |
| `strategy.canary.analysis` | Flow 7 SLO gate |
| `strategy.blueGreen.activeService` | Flow 2 active arrow |
| `strategy.blueGreen.previewService` | Flow 9 preview arrow |
| `trafficRouting.istio.virtualService` | Flow 4 mirror, Flow 5 header match |

---

End of visual flows.
