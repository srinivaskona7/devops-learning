# Architect Q&A — Kubernetes Advanced

Sixty-plus design questions you should be able to defend in a senior or staff-level review. Read, pause, then read the answer.

---

## Section A — CRDs and Operators

### 1. When do you write your own operator versus consuming an existing one?
Write your own when the domain has unique day-2 lifecycle that no community operator models, when you need to embed business invariants, or when the existing operator pulls in a runtime you cannot accept. Consume existing ones for databases, message brokers, and observability stacks where Cloud Native Computing Foundation operators are mature.

### 2. Operator versus Helm chart — when does the line cross?
Helm is enough if the lifecycle is install, upgrade, uninstall and the resource graph is static. The line crosses the moment you need runtime decisions: failover, backup, version-aware migration, or status-driven reconciliation. At that point Helm becomes a deployment artifact for your operator, not the controller itself.

### 3. CRD versioning — how do you plan it from day one?
Pick a single storage version, mark v1alpha1 as served-not-stored once v1beta1 lands, and provide conversion webhooks. Never delete a served version without a deprecation window. Store the canonical version in etcd, convert on read for older clients.

### 4. What is a CRD storage version and why does it matter?
Only one version is persisted in etcd. Conversion webhooks translate between served versions on the wire. If you change storage version, you must rewrite all stored objects via a migration job before retiring the old version, otherwise round-trip data loss occurs.

### 5. Structural schemas — required for what?
Required for v1 CRDs. They enable pruning of unknown fields, defaulting, and proper OpenAPI publishing for kubectl explain. Without them you lose validation guarantees and merge-patch becomes lossy.

### 6. Subresources — when do you enable status and scale?
Enable status whenever your controller owns a status field. It splits RBAC and prevents users from mutating status. Enable scale when the resource is meaningfully replica-counted and you want HPA compatibility.

### 7. Finalizers — design rules?
Finalizers are owned by a single controller. Always namespace them with your domain. Add before creating external state, remove only after external cleanup confirms. Never add a finalizer you cannot remove offline; you will brick deletion.

### 8. Owner references — when not to use them?
Avoid owner references across namespaces or to cluster-scoped owners from namespaced children. Garbage collection assumes same-namespace ownership. Cross-cutting deletion needs a controller, not GC.

### 9. Reconciler design — level versus edge triggered?
Always level-triggered. Read current state, compute desired state, converge. Edge-triggered designs accumulate drift and break on missed events. Use the workqueue for rate-limited retries, not for event ordering.

### 10. Status conditions — what schema?
Use the standard Kubernetes Conditions array with type, status, reason, message, lastTransitionTime, observedGeneration. Tooling, dashboards, and kubectl wait depend on this shape.

### 11. Generation versus observedGeneration — why both?
Generation increments on spec change. observedGeneration is what the controller has reconciled. The gap tells you whether status reflects current spec. Without it, status lies during rollouts.

### 12. CRD scope — namespaced versus cluster-scoped?
Namespaced for tenant-owned resources, cluster-scoped for platform primitives. Mixing them costs you RBAC clarity. When in doubt, namespaced.

---

## Section B — Admission Webhooks

### 13. Mutating versus validating — design pitfalls?
Mutating webhooks reorder unpredictably; never assume your sidecar inject runs last. Validating webhooks must be idempotent and side-effect-free. Both must respect timeoutSeconds and failurePolicy.

### 14. failurePolicy Fail or Ignore?
Fail for security policy enforcement. Ignore for advisory mutations like injection on best-effort namespaces. Default Fail, exempt kube-system, exclude your own namespace to avoid bootstrap deadlock.

### 15. How do you avoid a webhook bringing down the API server?
Set timeoutSeconds to 5 or less, scope namespaceSelector and objectSelector tightly, run the webhook in HA with PodDisruptionBudget, exempt the webhook namespace itself, and monitor admission latency as a SLI.

### 16. Webhook bootstrap dependency loop — how to break?
Exclude kube-system and the webhook namespace from selectors. Use cert-manager with a namespace not gated by the webhook. Pre-create the webhook deployment before installing the MutatingWebhookConfiguration.

### 17. Order of admission — what runs when?
Authentication, authorization, mutating admission, schema validation, validating admission, then persistence. Mutating webhooks run in unspecified order; reinvocationPolicy IfNeeded triggers a second pass if any later mutation occurs.

### 18. CEL ValidatingAdmissionPolicy — when over webhook?
For pure validation without external state, prefer CEL. No deployment, no certs, no webhook server. Use webhooks when you need cluster lookups, external API calls, or mutation.

### 19. Scoping by namespaceSelector and objectSelector?
Always set both. Without them you intercept every Pod in every namespace, including system pods. Performance and blast radius depend on tight selectors.

### 20. SideEffects field — why does it matter?
Declares whether your webhook has out-of-band effects. Required for dryRun support. Lying here breaks kubectl diff and apiserver dry-run flows.

---

## Section C — Scheduler

### 21. Scheduler plugin versus extender — choose how?
Plugins are in-process, low-latency, type-safe. Extenders are HTTP, language-agnostic, slow. Default to plugins. Extenders only when you cannot ship Go or need to integrate with an external scheduling brain.

### 22. Scheduling framework extension points?
PreFilter, Filter, PostFilter, PreScore, Score, NormalizeScore, Reserve, Permit, PreBind, Bind, PostBind. Pick the latest point that solves your problem; earlier hooks burn cycles on every pod.

### 23. Multi-scheduler patterns — when to run two?
When workload classes have fundamentally different policies: batch versus service, or GPU versus CPU. Use schedulerName to opt-in. Avoid running default scheduler twice.

### 24. Pod topology spread versus affinity?
Topology spread is the modern primitive: skew-aware, declarative, supports zones and nodes uniformly. Use affinity only for hard pinning or anti-co-location with another workload.

### 25. PriorityClass and preemption — design rules?
Define no more than five priority bands. Preemption respects PDBs but can still cause churn. Reserve highest band for system-critical only. Never let user workloads exceed system-cluster-critical.

### 26. DRA — Dynamic Resource Allocation — what changes?
DRA models devices like GPUs as first-class scheduled resources with claims, classes, and lifecycle. Replaces device plugin model for sharable, partitioned, or vendor-rich devices. Plan to migrate over multiple releases.

### 27. Gang scheduling — how to do it well?
Use a coscheduling plugin like Volcano or scheduler-plugins coscheduling. Mark pod groups with a label, the plugin reserves capacity all-or-nothing. Avoid hand-rolled gang via init containers.

---

## Section D — Service Mesh

### 28. Mesh adoption — sidecar or sidecarless?
Sidecar is mature, predictable, costly. Sidecarless via Istio ambient or Cilium service mesh is cheaper but younger. For greenfield with ops maturity, ambient. For brownfield with strict mTLS and existing skill, sidecar.

### 29. mTLS — strict, permissive, or off?
Permissive during rollout, strict in steady state, never off in shared clusters. Strict at namespace scope first, then mesh-wide. Have an emergency PeerAuthentication rollback ready.

### 30. Retries and timeouts — where to set them?
Per-route at the mesh, with budgets at the destination. Always set both. Unbounded retries amplify outages. Timeouts must be shorter than the upstream client timeout.

### 31. Mesh observability — what is required before adoption?
Distributed tracing with sampling, golden signals dashboards, and access logs at the gateway. Without these, mesh adds latency you cannot explain and failures you cannot debug.

### 32. Multi-cluster mesh topologies?
Primary-remote: one control plane, remote data planes. Multi-primary: control plane in each cluster, federated trust. Replicated: independent meshes joined by gateways. Choose by failure domain isolation needs.

### 33. East-west gateway — when needed?
For multi-cluster mesh when pods cannot route directly across clusters. Adds an extra hop and a mTLS termination point. Avoid if flat L3 is available.

### 34. WASM filters — production-ready?
For specific use cases yes: header rewrite, rate limit, custom auth. Watch for memory leaks and cold-start cost. Compile with strict resource limits, version your filters, ship via OCI.

---

## Section E — Gateway API

### 35. Gateway API versus Ingress — when to migrate?
Migrate when you need role separation between platform and app teams, protocol-rich routing, or multi-tenant gateways. Stay on Ingress for simple TLS-terminated HTTP with one team.

### 36. GatewayClass design?
One class per implementation: edge, internal, mesh. Owned by platform. Application teams reference classes, not implementations.

### 37. HTTPRoute attachment — same versus cross-namespace?
Cross-namespace requires ReferenceGrant. Use it for shared gateways. Same-namespace by default for tenant isolation.

### 38. ParentRefs design?
A route can attach to multiple parents. Use this for canary across gateways or for serving the same app on internal and external. Avoid mixing semantics on a single route.

### 39. TCP, UDP, GRPC routes — when?
TCPRoute for opaque L4. UDPRoute for DNS and similar. GRPCRoute for native gRPC matching including method names. Prefer GRPCRoute over HTTPRoute path-matching for gRPC.

### 40. Policy attachment pattern?
Define policies as CRDs that target Gateway, HTTPRoute, or Service. Use the targetRef pattern. Avoid annotation-based policy; it does not survive role separation.

---

## Section F — Multi-Cluster

### 41. Federation versus GitOps fan-out?
GitOps fan-out is simpler, scales well, and isolates failure. Federation centralizes control at the cost of a single point of failure and operational complexity. Default to fan-out unless you need cross-cluster placement decisions.

### 42. Cluster API — when to adopt?
When you manage more than five clusters, need declarative provisioning, and want consistent upgrades. The investment pays back at fleet scale, not at one or two clusters.

### 43. Service discovery across clusters?
Multi-cluster Services with ClusterSet, or mesh-based federation. Avoid DNS hacks across clusters; they break health and locality awareness.

### 44. Cross-cluster failover — design?
Active-active with health-weighted DNS or mesh locality routing. Active-passive with explicit promotion controlled by a runbook, never automatic across regions.

### 45. Workload identity across clusters?
SPIFFE IDs federated via SPIRE or mesh trust bundles. Avoid sharing service account tokens; they do not federate cleanly.

### 46. Policy distribution at fleet scale?
Kyverno or OPA policies stored in Git, applied via Flux or Argo per cluster. Policies remain local; reports aggregate centrally.

---

## Section G — eBPF and Dataplane

### 47. Cilium versus Calico — choose how?
Cilium for eBPF datapath, identity-based policy, and integrated mesh-lite. Calico for mature network policy, BGP at scale, and lower learning curve. Both are excellent; the team skill curve usually decides.

### 48. eBPF kube-proxy replacement — production ready?
Yes for Cilium and recent Kubernetes. Removes iptables scaling cliff, improves latency. Validate on your kernel version; eBPF features track kernel.

### 49. Network policy versus mesh policy?
Network policy at L3 or L4. Mesh policy at L7 with identity. Use both: network policy as the floor, mesh policy as the ceiling. Defense in depth.

### 50. Hubble or Cilium observability — when?
When you need flow-level visibility without running a full mesh. Adds modest CPU, gives you dropped-packet attribution and policy hit logs.

### 51. eBPF tc hooks — what do they replace?
iptables NAT, conntrack-heavy paths, and per-packet userspace decisions. Run earlier in the stack, scale linearly, but require kernel-level expertise to debug.

---

## Section H — Multi-Tenancy

### 52. Hard versus soft multi-tenancy?
Soft: namespaces, RBAC, network policy. Hard: separate clusters or virtual clusters with kube-apiserver isolation. PCI, HIPAA, or hostile tenants need hard.

### 53. Virtual clusters — when?
When you want per-tenant control planes without per-tenant nodes. Capsule, vCluster, or Kamaji. Adds complexity, gains isolation.

### 54. Quota strategy?
ResourceQuota per namespace, LimitRange for defaults, PriorityClass quotas to cap high-priority abuse. Quota at admission time prevents noisy-neighbor scheduling.

### 55. Tenant scheduling isolation?
Node selectors plus taints, with topology spread inside. Avoid dedicated nodes per tenant unless you accept the bin-packing loss.

### 56. RBAC at scale?
ClusterRoles with aggregation labels. Per-tenant Roles via bootstrap operators. Never grant cluster-admin to tenants; use namespace-admin role definitions.

### 57. Audit logging for tenants?
Audit policy with per-namespace metadata level minimum, request level for sensitive verbs. Ship audit to per-tenant sinks where compliance requires.

---

## Section I — Stateful and Storage

### 58. StatefulSet versus operator?
StatefulSet for stable identity and ordered rollout. Operator when you need backup, restore, failover, or topology-aware ops. Most databases need both.

### 59. CSI driver design considerations?
Implement Identity, Controller, Node services. Support snapshots if your storage does. Handle volume expansion. Set fsGroupPolicy correctly to avoid permission breakage.

### 60. Storage classes — how many?
One per performance tier and reclaim policy combination. Rarely more than five. Annotate the default; never have two defaults.

### 61. Topology-aware provisioning?
Set volumeBindingMode WaitForFirstConsumer for zonal storage. Without it pods schedule before storage, ending in cross-zone failures.

---

## Section J — API Extension Strategy

### 62. CRD versus aggregated API server?
CRD for 95 percent of cases. Aggregated API server when you need custom storage, non-etcd backends, or REST verbs Kubernetes does not model. Aggregated APIs cost you the entire API machinery you must reimplement.

### 63. Conversion webhook — design?
Stateless, fast, idempotent. Round-trip safe: convert v1 to v2 and back must equal original. Test with fuzzing.

### 64. Defaulting strategy?
Prefer CRD schema defaulting over mutating webhook. It runs without network calls, survives webhook outages, and is visible in OpenAPI.

### 65. Validation strategy?
CEL on CRD fields for cross-field rules. ValidatingAdmissionPolicy for cluster-wide rules. Webhooks only when you need external lookups.

---

## Section K — Operations and Reliability

### 66. SLOs for the control plane?
P99 admission latency, etcd write latency, scheduler bind latency, controller workqueue depth. Alert on burn rate, not single samples.

### 67. Etcd sizing and defrag?
8 GB DB size soft limit. Defrag during off-hours. Snapshot every 30 minutes. Three-node minimum, five for fault tolerance.

### 68. Upgrade strategy?
Skew is one minor version. Upgrade control plane first, then nodes. Test in non-prod with same CRDs and webhooks. Always have a rollback path.

### 69. Disaster recovery for the cluster itself?
Etcd snapshots offsite. CRD definitions in Git. Cluster API templates for rebuilding. Practice restore quarterly; untested backups are not backups.

### 70. Cost levers at scale?
Right-size requests via VPA recommendations, bin-pack with node-pool consolidation, use spot for batch, right-tier storage. Operator cost dwarfs node cost above a threshold; consolidate operators.

---

## Closing principles

- Reconcile, do not orchestrate.
- Validate at admission, default at schema, mutate sparingly.
- Push policy to the platform, not the application.
- Choose boring technology that has a working operator.
- Make every extension observable from day zero.
