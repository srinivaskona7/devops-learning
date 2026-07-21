# Architect-Level Q&A — Kubernetes Deployment Strategies

Forty-plus questions and answers for senior engineers, SREs, and architects.
Topics: workload classification, SLO-gated rollouts, multi-cluster blue/green,
mesh vs ingress traffic split, rollback economics, canary SLI design, and
regulatory rollouts.

---

## Section 1 — Choosing the right strategy per workload class

### Q1. How do you classify workloads to pick a strategy?

Use four axes: **statefulness**, **blast radius**, **rollback latency
requirement**, and **change frequency**. Stateless + low blast radius + frequent
change = rolling. Stateful + high blast radius + slow rollback = blue/green.
Customer-facing + revenue-critical = canary with SLO gates.

### Q2. Why is rolling the wrong default for stateful workloads?

Rolling assumes pods are interchangeable. StatefulSets have stable identities,
PV bindings, and ordered termination. A naive rolling update on a quorum
database can break the quorum mid-roll. Use partitioned `OnDelete` rollouts
with manual or operator-driven coordination.

### Q3. What strategy fits a payment processing service?

Blue/green with shadow traffic for at least one full business cycle, then
canary at 1 percent for 24 hours, then 10 percent, then 50, then 100 — gated
by latency p99, error rate, and a custom SLI for transaction success.

### Q4. Internal admin tools — what strategy?

Rolling update is fine. Blast radius is low, users are tolerant, no SLO
contracts. Don't over-engineer.

### Q5. ML inference service with cold-start of 30s — what strategy?

Blue/green is mandatory. A rolling update creates a window where a fraction of
requests hit cold pods. Pre-warm the green stack, then flip the Service.

### Q6. Batch / cron workloads?

Strategy is irrelevant for the running job — replace the image and let the
next scheduled run pick it up. Use `imagePullPolicy: Always` and tag immutably.

### Q7. WebSocket-heavy service?

Sticky long-lived connections fight rolling updates. Use blue/green so old
connections drain naturally on the old stack while new connections land on
green. Set `terminationGracePeriodSeconds` high enough to drain.

---

## Section 2 — SLO-gated rollouts

### Q8. What is an SLO-gated rollout?

A rollout that auto-promotes or auto-aborts based on real-time SLI
measurements against an SLO target. Argo Rollouts `AnalysisTemplate` and
Flagger metric checks both implement this.

### Q9. Which SLIs should gate a canary?

Minimum three: **availability** (success rate), **latency** (p95 or p99), and
a **business SLI** (e.g., orders/min, login success). Add **saturation**
(CPU, memory, queue depth) for early warning.

### Q10. How long should the analysis window be?

Long enough for statistical significance. For high-traffic services 5 min is
usable; for low-traffic services use 15-30 min or count-based windows. Below
5 min you risk false positives from normal variance.

### Q11. How do you avoid noisy SLOs aborting good rollouts?

Use multi-window multi-burn-rate alerts. Only abort when both a fast (5 min)
and slow (1 hour) burn-rate exceed thresholds. This is the same pattern
Google SRE uses for paging.

### Q12. What is error-budget-based rollout pacing?

If your service has consumed 80 percent of its monthly error budget, slow or
freeze rollouts. If at 0 percent burn, allow aggressive canaries. Codify the
policy in your platform.

### Q13. How do you handle SLI lag (Prometheus scrape delay)?

Add a settle period after each traffic shift before sampling — typically
2-3x scrape interval. Argo Rollouts `initialDelay` field handles this.

### Q14. Should the analysis abort the rollout or just pause it?

Pause first. Auto-abort only on hard failures (5xx spike, pod crashloop).
Let humans decide on soft signals. False positives that auto-rollback erode
trust in the platform.

---

## Section 3 — Multi-cluster blue/green

### Q15. Why go multi-cluster blue/green vs in-cluster?

Blast radius. An in-cluster blue/green still shares the same control plane,
node pools, and CNI. Multi-cluster isolates infrastructure-level blast
radius — control plane upgrades, CNI changes, region failures.

### Q16. How do you switch traffic between clusters?

Three options: **global load balancer** (GCLB, AWS Global Accelerator),
**DNS weighted records** (Route53, CloudFlare), or **anycast IP**. Avoid
DNS-only flips for critical services — TTL caching defeats instant rollback.

### Q17. How do you keep state consistent across clusters?

You don't run state in both. Either (a) shared regional database with both
clusters as readers, single writer, or (b) async replication with one cluster
as the primary at any time. Cluster-level blue/green is for stateless tiers.

### Q18. What about session affinity across clusters?

Use signed JWTs or external session stores (Redis cluster, DynamoDB) so
either cluster can serve any request. Cookie-based sticky sessions tied to
a specific cluster IP break the model.

### Q19. How do you validate the green cluster before flipping?

Synthetic transactions hitting the green cluster's ingress directly, plus
internal smoke tests, plus shadow traffic from the blue cluster's edge. Only
flip user traffic after all three pass.

### Q20. What's the rollback contract for cluster-level blue/green?

Single global LB weight change should restore blue in under 60 seconds
end-to-end (including DNS or LB convergence). Test this monthly.

---

## Section 4 — Traffic split: mesh vs ingress

### Q21. When does mesh-based traffic split beat ingress-based?

When you need: per-route splitting, per-header splitting, fine-grained
percentages (1 percent), mTLS enforcement, or in-cluster east-west splits.
Ingress-based is coarse and edge-only.

### Q22. Concrete example of header-based canary in Istio?

A `VirtualService` matching `header: x-canary: true` routes 100 percent to
the canary subset. Everyone else hits stable. Combined with feature flags,
this enables internal-user-only canaries.

### Q23. What is the cost of running a service mesh just for traffic split?

Sidecar overhead (50-150 MB RAM per pod), latency tax (1-3 ms per hop),
operational complexity (control plane upgrades). If traffic split is your
only need, NGINX Ingress with canary annotations is cheaper.

### Q24. Linkerd vs Istio for canary?

Linkerd: simpler, lighter, opinionated. Use when you want traffic split +
mTLS without extra knobs. Istio: more features (auth policies, egress
control, multi-cluster), heavier. Use when you need the surface area.

### Q25. How does Gateway API compare?

Gateway API is the future. It standardises traffic split semantics across
implementations (NGINX, Envoy, Contour, Istio). Adopt it for new platforms;
existing Ingress + annotations stay until Gateway API matures in your
chosen controller.

### Q26. Sticky sessions during a canary — how?

Use `consistent hash` load balancing on a cookie or header. Once a user
hits canary, they keep hitting canary for the analysis window. Both Istio
and NGINX support this. Without stickiness, A/B comparisons get noisy.

---

## Section 5 — Rollback economics

### Q27. What is the cost of a rollback?

Direct: lost user trust, support tickets, on-call hours. Indirect: feature
delivery slowdown, engineering morale. Quantify it: assign dollar amount to
each rollback. Use it to justify investment in canary tooling.

### Q28. When is a rollback more expensive than rolling forward?

When the bug is minor, fix is trivial, and rollback would undo critical
schema migrations or data writes. Rule: if rollback requires data surgery,
roll forward with a hotfix.

### Q29. How do you make rollback safer than roll-forward?

(1) Backward-compatible schemas. (2) Feature flags wrapping risky code.
(3) Automated rollback drills in CI. (4) Versioned configs. (5) Immutable
infrastructure — old image still pullable.

### Q30. Why is blue/green the cheapest rollback?

The old stack is still hot. Flipping the Service selector reverts in
seconds. Cost paid upfront (double infrastructure) is the insurance premium.

### Q31. Canary rollback — what does it cost?

Cheap if caught early (pause before promotion = no impact). Expensive if
caught at 50 percent — you've already exposed half your users.

---

## Section 6 — Canary analysis SLI design

### Q32. How do you design a canary SLI from scratch?

Start with the user journey. Identify the critical user-perceptible steps.
For each step define: success definition, measurement source, acceptable
threshold, statistical window. Build dashboards for each. Then convert to
machine-readable AnalysisTemplate.

### Q33. What's wrong with using "error rate < 1 percent" as the only SLI?

It misses latency degradations, partial failures, and silent regressions.
Use a composite: error rate AND p99 latency AND business KPI.

### Q34. How do you compare canary vs stable statistically?

Use ratio queries in Prometheus: `canary_error_rate / stable_error_rate`.
A ratio above 1.5 (50 percent worse) for sustained windows = abort. This
auto-adjusts to baseline noise.

### Q35. Mann-Whitney U vs simple threshold for canary analysis?

Threshold is simpler and works for most cases. Statistical tests (Kayenta
uses these) help when baseline is noisy or traffic is low. Start with
thresholds; add statistical tests when you outgrow them.

### Q36. How do you handle metric cardinality blowup during canary?

Tag metrics with `version=canary|stable` only. Don't add per-pod labels —
that explodes cardinality. Aggregate at the deployment label.

---

## Section 7 — Regulatory rollouts

### Q37. PCI-DSS rollout requirements — what changes?

Audit trail for every traffic-shift step (who, when, what version, what
SLO state). Approval gates between phases. Encrypted artifact provenance
(SLSA). Canary windows long enough to surface fraud patterns (24-48 hours
typical).

### Q38. HIPAA — special considerations?

PHI must not leak via shadow traffic — sanitise or use the same encryption
in shadow as production. Rollback procedures must be in the BAA. Document
that no PHI is logged in rollout pipelines.

### Q39. SOX-controlled financial systems — strategy?

Blue/green with mandatory dual-control approval (segregation of duties).
Change advisory board sign-off before traffic flip. Immutable audit log
in a separate retention bucket.

### Q40. Healthcare medical-device-adjacent services?

Pre-prod conformance testing required by FDA / IEC 62304. Rollouts gated
by validation suite results stored as evidence. Often blue/green with full
regression suite running on green before flip.

### Q41. How do you prove "we rolled back within RTO" to an auditor?

Capture rollout events as Kubernetes Events + send to immutable storage
(S3 with object lock, or write-once log service). Argo Rollouts emits
events for every step; pipe them to your audit sink.

---

## Section 8 — Bonus: edge cases

### Q42. Deployment + HPA — does HPA fight rolling updates?

It can. HPA may try to scale during the roll. Set `progressDeadlineSeconds`
to give the rollout time, and consider pausing HPA during deployments via
operator hooks.

### Q43. PodDisruptionBudget interaction with rolling updates?

PDB is the safety net — it prevents rolling from killing too many pods.
Set `minAvailable` to N-1 for quorum systems, percentage for stateless.

### Q44. Init containers + slow startup — what breaks?

Rolling update can wait forever if `readinessProbe.initialDelaySeconds` is
too low. Always tune probes; use `startupProbe` for slow-starting apps.

### Q45. How do you do progressive delivery for CronJobs?

You don't. Deploy the new CronJob as a separate name (`-canary` suffix),
schedule it less often, watch it succeed for N runs, then swap and retire.

---

End of architect Q&A. Continue to `eli10.md` for the gentle explanation, or
`visual-flows.md` for the diagrams.
