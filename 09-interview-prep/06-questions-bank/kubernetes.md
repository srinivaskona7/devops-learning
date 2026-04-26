# Kubernetes Q&A Bank

These questions are the ones I've actually been asked / would ask. K8s is the largest section because every DevOps loop drills it deeply — control plane, scheduling, networking, storage, and operational debugging.

## How to use

Say each answer out loud, 60-second ceiling. For architecture questions, sketch the components — interviewers care about the mental model. Always state the trade-off when there's a choice.

---

## Core Architecture

**Q1. Walk me through the Kubernetes control plane.**
API server (sole entry point, persists to etcd). etcd (distributed key-value store, source of truth). Scheduler (assigns pods to nodes based on filters/scores). Controller manager (runs control loops: deployment, replicaset, node, endpoint). Cloud-controller-manager (cloud provider integrations). On nodes: kubelet (pod lifecycle), kube-proxy (Service networking), container runtime (containerd/CRI-O).

**Q2. What is etcd and why is it special?**
Distributed key-value store using Raft consensus. Single source of truth for cluster state — every object lives there. Needs odd-number quorum (3 or 5). Performance-sensitive: requires SSD, low-latency network. Backup is non-negotiable.

**Q3. What happens when you `kubectl apply -f deploy.yaml`?**
kubectl validates and POSTs to API server. API server authenticates (cert/token), authorizes (RBAC), runs admission controllers (mutating then validating), persists to etcd. Deployment controller observes new Deployment, creates ReplicaSet. ReplicaSet controller creates Pods. Scheduler assigns nodes. Kubelet on node pulls image, starts containers via CRI.

**Q4. Difference between Deployment, ReplicaSet, Pod?**
Pod: smallest deployable unit, one or more containers sharing network/storage. ReplicaSet: ensures N pod replicas. Deployment: manages ReplicaSets to enable rolling updates and rollbacks. You almost always create Deployments, never raw ReplicaSets.

**Q5. What is a controller in Kubernetes?**
A control loop that watches desired state (spec) vs actual state (status) and reconciles. Pattern: list/watch resources via API, diff, take action, update status. All built-in controllers (deployment, statefulset, job) follow this; CRDs + operators extend it.

**Q6. Explain reconciliation.**
Continuously compare observed state to desired state and act to converge. Idempotent — safe to run repeatedly. If a pod dies, the ReplicaSet controller notices count < desired and creates a new pod. The core K8s pattern.

**Q7. What's a CRD?**
CustomResourceDefinition — extends the API with new resource types. Combined with a controller (operator pattern), turns Kubernetes into a platform for any stateful app or workflow. Examples: Prometheus, Cert-Manager, ArgoCD all use CRDs.

**Q8. What is the operator pattern?**
A controller that encodes operational knowledge for a specific app. Reconciles a CRD into the underlying K8s primitives (Pods, PVCs, Services). Handles upgrades, backups, failure recovery. Built with Operator SDK or Kubebuilder.

---

## Workloads & Pods

**Q9. What's in a Pod spec beyond containers?**
nodeSelector/affinity, tolerations, volumes, initContainers, securityContext, serviceAccount, dnsPolicy, restartPolicy, terminationGracePeriodSeconds, priorityClassName, topologySpreadConstraints.

**Q10. Init containers vs sidecars?**
Init containers run sequentially before main containers, used for setup (wait for dep, fetch config). Sidecars run alongside main containers (logging, proxy, certs). K8s 1.29+ has native sidecar support via `restartPolicy: Always` on init containers.

**Q11. What's a StatefulSet and when do you use one?**
For stateful apps needing stable identity and storage: ordered start/stop, stable DNS names (`pod-0.svc`), per-replica PVCs. Use for databases, queues, leader-elected apps. Trade-off: slower scaling than Deployment.

**Q12. DaemonSet?**
One pod per node (or matching nodeSelector). Used for node-level agents: log collectors (fluentbit), metrics (node-exporter), CNI plugins, CSI drivers.

**Q13. Job vs CronJob?**
Job runs pods until N successful completions. CronJob creates Jobs on a schedule (cron syntax). Watch out for: concurrency policy, history limits, missed deadlines (startingDeadlineSeconds), and clock skew.

**Q14. How does K8s decide a pod is ready?**
Readiness probe must pass. Pod is added to Service endpoints only when Ready. Liveness probe restarts the container on failure. Startup probe protects slow-starting apps from premature liveness kills. Without probes, K8s assumes ready immediately.

**Q15. What's the difference between liveness, readiness, startup probes?**
Liveness: should this container be restarted? Readiness: should this pod receive traffic? Startup: has the app finished initializing? (suspends liveness/readiness during startup). All can be exec, httpGet, tcpSocket, or grpc.

**Q16. What's the pod lifecycle?**
Pending → ContainerCreating → Running → (Succeeded | Failed). PodCondition flags: PodScheduled, Initialized, ContainersReady, Ready. Terminating phase on deletion: SIGTERM → grace period → SIGKILL.

**Q17. What happens when you delete a pod?**
API marks pod for deletion (sets deletionTimestamp). Endpoints controller removes pod from Service. Kubelet sends SIGTERM to containers, runs preStop hook if defined, waits terminationGracePeriodSeconds, then SIGKILL. Pod removed from etcd after kubelet confirms.

**Q18. What is a preStop hook used for?**
Run a command before SIGTERM — typically to deregister from upstream LBs or signal connection draining. Combined with grace period, ensures in-flight requests complete before pod dies.

---

## Scheduling

**Q19. How does the scheduler pick a node?**
Two phases: Filtering (predicates: nodeSelector, taints, resources, affinity rules — eliminate ineligible nodes) then Scoring (priorities: spread, image locality, resource balance — rank remaining). Picks highest score. Pluggable via scheduler framework.

**Q20. Difference between requests and limits?**
requests: guaranteed resources, used by scheduler for placement. limits: hard ceiling — CPU is throttled, memory OOM-kills. Set requests=limits for predictable QoS (Guaranteed class) or only requests for Burstable.

**Q21. Explain QoS classes.**
Guaranteed: requests=limits for all containers, all resources. Burstable: at least one request set, not all equal to limits. BestEffort: no requests/limits. Eviction order under pressure: BestEffort → Burstable → Guaranteed.

**Q22. What are taints and tolerations?**
Taints repel pods from a node (`kubectl taint nodes node1 key=val:NoSchedule`). Pods need a matching toleration to land there. Used to dedicate nodes (GPU, infra) or cordon for maintenance.

**Q23. nodeAffinity vs nodeSelector?**
nodeSelector is simple key=value matching. nodeAffinity supports operators (In, NotIn, Exists), required vs preferred, multiple expressions. Always use affinity for new specs.

**Q24. What is podAntiAffinity used for?**
Spread pods across failure domains (don't put two replicas on same node/zone/rack). Required (hard constraint, may leave pods Pending) or preferred (best-effort scoring).

**Q25. What are topologySpreadConstraints?**
Modern alternative to anti-affinity for spreading. Specify topologyKey (zone, hostname), maxSkew, whenUnsatisfiable (DoNotSchedule | ScheduleAnyway). Cleaner semantics for "spread across zones evenly".

**Q26. Explain PodDisruptionBudget.**
Limits voluntary disruptions (drain, eviction) — `minAvailable: 2` or `maxUnavailable: 1`. Doesn't affect involuntary disruptions (node crash). Critical for maintaining quorum during cluster ops.

**Q27. What's a PriorityClass?**
Numeric priority on pods. Scheduler prefers higher-priority pods. With preemption enabled, high-pri pods can evict low-pri ones to fit. Used for system-critical workloads.

**Q28. How does HPA work?**
HorizontalPodAutoscaler queries metrics (CPU/memory from metrics-server, custom from Prometheus adapter), computes desired replicas = ceil(currentReplicas × currentMetric / targetMetric), updates Deployment.spec.replicas. Default sync 15s. Has stabilization window to avoid flapping.

**Q29. VPA vs HPA?**
HPA scales replica count horizontally. VPA scales requests/limits vertically (recommendations or auto-applied). Don't combine on the same resource without care — VPA's "Auto" mode requires pod restart.

**Q30. What is Karpenter / Cluster Autoscaler?**
Cluster Autoscaler: scales node groups when pods are unschedulable. Karpenter: just-in-time node provisioning, picks instance types based on pending pod requirements. Karpenter is faster and more cost-efficient on AWS.

---

## Networking

**Q31. Explain the Kubernetes networking model.**
Every pod gets a routable IP. All pods can reach all pods without NAT. All nodes can reach all pods. Implemented by CNI plugins. Services provide stable virtual IPs. Network model is opinionated; CNI gives flexibility.

**Q32. What is a CNI plugin?**
Container Network Interface — spec for pluggable pod networking. Plugins: Calico (BGP, NetworkPolicy), Cilium (eBPF, observability), Flannel (simple overlay), AWS VPC CNI (native AWS IPs), Weave. Picked at cluster install.

**Q33. Difference between ClusterIP, NodePort, LoadBalancer?**
ClusterIP: internal-only virtual IP, default. NodePort: exposes on every node's IP at a high port (30000-32767). LoadBalancer: provisions cloud LB pointing to NodePort. ExternalName: DNS CNAME, no proxying.

**Q34. How does a Service route to pods?**
Endpoints/EndpointSlice controller watches pods matching the Service selector, populates endpoints. kube-proxy on each node programs iptables (or IPVS) rules to DNAT ServiceIP:port to a random pod IP:port. eBPF dataplanes (Cilium) bypass iptables.

**Q35. What is an EndpointSlice and why was it introduced?**
Replacement for Endpoints object. Splits endpoint list into multiple objects (max 100 per slice), reducing watch traffic and etcd load for large Services (think 1000+ endpoints).

**Q36. What's an Ingress?**
L7 routing: hostname/path → Service. Implemented by an Ingress Controller (nginx, traefik, HAProxy, AWS ALB). One LB serving many apps. Replaced increasingly by Gateway API for advanced routing.

**Q37. Ingress vs Gateway API?**
Gateway API is the successor — role-oriented (GatewayClass for infra, Gateway for cluster ops, HTTPRoute for app teams), supports multi-protocol, header-based routing, traffic splitting natively. Use Gateway API for new clusters.

**Q38. What is a NetworkPolicy?**
Pod-level firewall — selector-based rules for ingress/egress. Default-allow until any policy selects a pod, then default-deny for that direction. Requires CNI support (Calico, Cilium). Use to enforce zero-trust microsegmentation.

**Q39. How does DNS work in K8s?**
CoreDNS runs as a Deployment, exposed via kube-dns Service (ClusterIP). Pod's `/etc/resolv.conf` points at it. Resolves `service.namespace.svc.cluster.local`. Headless services return all pod IPs (A records).

**Q40. What's a headless Service?**
ClusterIP: None. No virtual IP, no kube-proxy load balancing. DNS returns pod IPs directly. Used for StatefulSets (stable per-pod DNS) or client-side load balancing.

**Q41. Explain ExternalTrafficPolicy.**
On NodePort/LoadBalancer Services. Cluster (default): SNAT, traffic can hop nodes, loses client IP, even distribution. Local: only routes to pods on the receiving node, preserves client IP, but uneven if pods aren't on every node.

**Q42. What is service mesh and when do you need one?**
Sidecar (or ambient) proxies that handle mTLS, traffic shifting, retries, observability between services. Examples: Istio, Linkerd. Need it when: zero-trust mTLS, fine-grained traffic policy, deep RPC observability across many services. Skip if you have <10 services.

---

## Storage

**Q43. Explain PV, PVC, StorageClass.**
PV (PersistentVolume): a piece of storage in the cluster, provisioned by admin or dynamically. PVC (Claim): a user's request for storage (size, access mode). StorageClass: defines a provisioner + params for dynamic PV creation. PVC binds to a matching PV.

**Q44. Access modes?**
ReadWriteOnce (RWO): one node read-write. ReadOnlyMany (ROX): many nodes read-only. ReadWriteMany (RWX): many nodes read-write — needs NFS/EFS/CephFS. ReadWriteOncePod (RWOP, 1.27+): one pod only.

**Q45. What is a CSI driver?**
Container Storage Interface — plugin spec for storage backends. Drivers handle Provision/Attach/Mount. Examples: ebs.csi.aws.com, file.csi.azure.com, ceph-csi. Standardizes storage integration across runtimes.

**Q46. ReclaimPolicy options?**
Retain: PV kept after PVC deletion (manual cleanup). Delete: underlying volume deleted with PV (default for dynamic). Recycle: deprecated. Set Retain for prod data.

**Q47. How do you resize a PVC?**
Edit PVC `spec.resources.requests.storage`. Requires StorageClass `allowVolumeExpansion: true` and CSI driver support. Filesystem expansion may need pod restart depending on driver.

**Q48. What is a VolumeSnapshot?**
CSI feature for point-in-time copies. VolumeSnapshotClass + VolumeSnapshot resource. Restore by creating a PVC with `dataSource` pointing at the snapshot. Used for backups and clone-and-test workflows.

**Q49. Why don't you use emptyDir for important data?**
emptyDir lives on the node's local disk, deleted when the pod is removed. No persistence across reschedules. Use for cache, scratch space, sidecar buffers — never for state.

---

## Configuration & Secrets

**Q50. ConfigMap vs Secret?**
ConfigMap: non-sensitive config as key-value or files. Secret: same shape, base64-encoded (NOT encrypted by default — etcd encryption-at-rest is separate). Both mountable as env vars or files. Prefer files (env vars leak via process listings).

**Q51. How do you rotate a Secret consumed by a pod?**
Mounted as file: kubelet refreshes the file (default ~60s). Mounted as env var: pod must restart to pick up changes. Use Reloader/Stakater or a sidecar to trigger restarts. Better: use external secrets operator with versioned secrets.

**Q52. Are Kubernetes Secrets actually secret?**
Out of the box, no — base64 ≠ encryption. Anyone with `get secret` RBAC sees the plaintext. Mitigations: encryption at rest in etcd (KMS provider), tight RBAC, External Secrets Operator with cloud KMS, sealed-secrets for GitOps.

**Q53. What is downward API?**
Mechanism to expose pod metadata (name, namespace, labels, IP, resource limits) to containers as env vars or files. Useful for self-aware apps and structured logging.

---

## RBAC & Security

**Q54. Explain RBAC components.**
Role/ClusterRole: set of permissions (verbs on resources). RoleBinding/ClusterRoleBinding: grant a role to subjects (users, groups, ServiceAccounts). Role is namespaced; ClusterRole is cluster-wide. ClusterRole + RoleBinding scopes a cluster-wide role to a namespace.

**Q55. ServiceAccount vs User?**
User: external identity (cert, OIDC) for humans. ServiceAccount: in-cluster identity for pods, mounted as a token. Pods authenticate to API server using the SA token.

**Q56. What is Pod Security Admission?**
Built-in admission controller (replaces PodSecurityPolicy). Enforces three profiles: Privileged, Baseline, Restricted. Set per-namespace via labels. Restricted denies privilege escalation, host namespaces, root, etc.

**Q57. How do you give a pod permissions to call AWS APIs?**
IRSA: associate a ServiceAccount with an IAM role via OIDC. Pod gets temporary AWS credentials via projected token + AWS SDK. Avoid putting AWS keys in Secrets.

---

## Observability & Debugging

**Q58. A pod is stuck in Pending. How do you debug?**
`kubectl describe pod <name>` — Events section reveals: insufficient CPU/memory, no nodes match nodeSelector/affinity, taints not tolerated, PVC unbound, image pull backoff. Then check node capacity: `kubectl describe nodes`.

**Q59. CrashLoopBackOff — walk me through diagnosis.**
`kubectl logs <pod> --previous` for the prior crash output. `describe` for exit code (137=OOM, 1=app error). Check liveness probe — too aggressive can kill healthy slow apps. Check resource limits, secrets/configmaps mounted correctly, command/args.

**Q60. ImagePullBackOff causes?**
Wrong image name/tag, private registry without imagePullSecret, registry rate limits (DockerHub), expired auth token, network egress blocked, or platform mismatch (arm vs amd64). `describe` shows the registry error.

**Q61. How do you debug a Service that isn't routing?**
`kubectl get endpoints <svc>` — empty means selector doesn't match any Ready pods. Check pod labels match Service selector, check pod readiness probe, check NetworkPolicy isn't blocking, `kubectl exec` into another pod and `curl <svc-name>`.

**Q62. Pod can't reach external internet.**
NetworkPolicy egress restriction, CNI misconfig, NAT gateway down, DNS broken (CoreDNS down, upstream resolver), node has no route. Test with `kubectl exec -- nslookup google.com` then `curl -v`.

**Q63. How do you find which pod is using all the cluster CPU?**
`kubectl top pod -A --sort-by=cpu`. Requires metrics-server. For deep dive, use Prometheus + Grafana with kube-state-metrics + cAdvisor.

**Q64. What does `kubectl describe node` tell you?**
Conditions (Ready, MemoryPressure, DiskPressure, PIDPressure), allocatable vs capacity, allocated requests, taints, lease info, recent events. First stop for "is this node healthy?".

---

## Upgrades & Operations

**Q65. How do you upgrade a Kubernetes cluster?**
Always one minor version at a time. Backup etcd. Upgrade control plane first (kube-apiserver, controller-manager, scheduler), then nodes (drain → upgrade kubelet/kube-proxy → uncordon). Check API deprecations with `kubectl deprecations` plugin or pluto.

**Q66. What is a rolling update strategy?**
Default for Deployment. maxSurge (extra pods over desired during update) and maxUnavailable (how many can be down) control rollout pace. Common: 25% / 25%. For critical: maxUnavailable: 0.

**Q67. Difference between rolling update and recreate?**
Rolling: gradually replace old pods with new. No downtime if probes are correct. Recreate: kill all old, then start new. Brief downtime but ensures only one version runs at a time — needed for breaking schema changes.

**Q68. Blue/green vs canary?**
Blue/green: full second environment, switch traffic atomically (instant rollback). Canary: gradual traffic shift to new version (5% → 50% → 100%) with monitoring gates. Canary needs traffic-splitting (Service Mesh, Argo Rollouts, Flagger).

**Q69. How do you rollback a Deployment?**
`kubectl rollout undo deployment/foo` (previous revision) or `--to-revision=N`. History via `kubectl rollout history`. Revision count controlled by `revisionHistoryLimit`.

**Q70. What's a finalizer and why does it matter?**
A string in `metadata.finalizers`. Object can't be deleted until all finalizers are removed (controllers do cleanup, then remove their finalizer). Stuck deletes usually mean a finalizer's controller is dead — `kubectl edit` to remove only as last resort.

---

## etcd & Backup

**Q71. How do you back up etcd?**
`etcdctl snapshot save backup.db` against the etcd endpoint with certs. Schedule via CronJob. Test restores regularly — untested backups don't exist. Managed K8s (EKS, GKE) handles this for you.

**Q72. What happens if etcd loses quorum?**
API server goes read-only or unavailable. No new pods scheduled, no scaling, no config changes. Existing pods continue running (data plane unaffected). Restore from snapshot or rebuild.

---

## Custom Resources & Extensions

**Q73. What is admission control?**
Phase after authn/authz, before persistence. Mutating admission webhooks modify objects (inject sidecars, defaults). Validating webhooks accept/reject. Examples: OPA Gatekeeper, Kyverno, cert-manager.

**Q74. Explain operator pattern with an example.**
Prometheus Operator: defines `Prometheus`, `ServiceMonitor`, `AlertmanagerConfig` CRDs. Its controller reconciles these into StatefulSets, ConfigMaps, Services. Users get high-level config; operator handles low-level details.

**Q75. What is GitOps?**
Git as source of truth for cluster state. Agents (ArgoCD, Flux) reconcile cluster to match repo. Benefits: audit log, easy rollback, consistent across envs, pull model (no kubeconfig in CI). Pair with PR-based approvals.

---

## Cost & Multi-Tenancy

**Q76. How do you implement multi-tenancy?**
Soft: namespaces + RBAC + ResourceQuota + LimitRange + NetworkPolicy. Hard: separate clusters or vCluster/Capsule. Choice depends on trust level — you can't fully isolate tenants on shared kernel.

**Q77. What is a ResourceQuota?**
Namespace-level cap on aggregate resources: CPU/memory requests+limits, count of objects (pods, secrets, PVCs), storage. Pods that would exceed quota are rejected at admission.

**Q78. LimitRange?**
Default + min/max per container in a namespace. Auto-applies requests/limits if user omits them. Prevents BestEffort pods from sneaking in.

**Q79. How do you reduce cluster cost?**
Right-size requests with VPA recommendations. Use Spot/Preemptible for stateless. Karpenter for bin-packing. Scale down dev clusters off-hours. Use ARM nodes (Graviton). Set cluster-autoscaler scale-down sensitivity. Track spend per namespace with Kubecost/OpenCost.

---

## Misc / Trivia

**Q80. Difference between `kubectl apply` and `create`?**
`create` is imperative — fails if object exists. `apply` is declarative — creates or merges with three-way diff (last-applied annotation). Always use apply for GitOps.

**Q81. What does `kubectl rollout status` block on?**
Waits until updated replicas == desired and old replicas == 0. Used in CI to gate post-deploy steps. Default timeout is forever — set `--timeout=5m`.

**Q82. How does `kubectl exec` work?**
kubectl asks API server to exec in pod. API server hits kubelet's exec endpoint. Kubelet uses CRI to invoke runtime exec, streams stdin/stdout over SPDY/WebSocket back through API server to kubectl.

**Q83. What is a sidecar container?**
A container in the same pod that supports the main app: log shipper, proxy (Envoy), secrets fetcher (Vault agent). Shares network and (often) volumes with the main container.

**Q84. What happens when a node goes NotReady?**
kubelet stops reporting heartbeats. After `node-monitor-grace-period` (default 40s), node marked NotReady. After `pod-eviction-timeout` (default 5m), pods marked for deletion and rescheduled. StatefulSet pods need manual intervention if storage doesn't auto-detach.
