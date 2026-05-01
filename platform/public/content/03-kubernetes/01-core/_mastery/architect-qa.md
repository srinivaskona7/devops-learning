# Architect-Level Q&A — Kubernetes Core

60+ questions you should be able to answer cold in a senior design review. Grouped by topic.

## A. Multi-tenant Cluster Design

### Q1. When do you choose hard multi-tenancy over soft?
Hard tenancy (separate clusters or virtual clusters via vcluster/Capsule) when tenants are mutually distrusting, have regulatory boundaries (PCI, HIPAA), or wildly divergent SLOs. Soft tenancy (namespaces + RBAC + NetworkPolicy + ResourceQuota) when tenants are internal teams with comparable trust levels.

### Q2. What are the four enforcement layers in soft multi-tenancy?
1. RBAC for API access scoping
2. NetworkPolicy for east-west traffic
3. ResourceQuota and LimitRange for resource fairness
4. PodSecurity admission for workload isolation

### Q3. Why is `kube-system` a tenancy risk?
Cluster-scoped controllers run there with cluster-admin. A tenant who gets pod-exec into a privileged daemonset escapes namespace isolation. Always pin tenant workloads to dedicated node pools and use admission to block hostPath, hostNetwork, and privileged.

### Q4. How do you handle DNS noisy-neighbor in shared clusters?
NodeLocal DNSCache eliminates per-pod conntrack churn against kube-dns. For very high QPS tenants, set per-namespace CoreDNS rate limiting via the rewrite plugin and monitor SERVFAIL by namespace.

### Q5. Should you give tenants their own ingress controller?
Yes when SLA isolation matters. Run per-tenant ingress-nginx in its own namespace with `--ingress-class=tenant-a`. Shared ingress is fine for read-mostly low-RPS tenants.

### Q6. How do you bill tenants accurately?
OpenCost or Kubecost emits per-namespace cost using node prices, allocation, and idle. Augment with custom labels (`team=`, `cost-center=`) enforced by Kyverno admission so untagged pods are rejected.

## B. etcd Sizing and Operations

### Q7. What is the practical etcd object limit per cluster?
Recommended max DB size is 8 GiB. In practice you start hurting around 4 GiB with slow `LIST` calls and watch lag. Object count target is under 200k for healthy operation.

### Q8. How do you size etcd disks?
NVMe SSDs only. Sustained write IOPS budget of 50 MB/s minimum, p99 fsync under 10 ms. Use `etcdctl check perf` and watch `etcd_disk_wal_fsync_duration_seconds`.

### Q9. What is the etcd memory rule of thumb?
Plan for 8 GB RAM minimum, 16 GB for clusters with 1000+ nodes. The full keyspace lives in memory.

### Q10. How frequently should etcd be defragmented?
When `etcd_mvcc_db_total_size_in_use_in_bytes` divided by `etcd_mvcc_db_total_size_in_bytes` falls below 0.5. Typically weekly on busy clusters, rolling one member at a time.

### Q11. What is the failure mode of an etcd write quorum loss?
API server goes read-only-ish (mutating calls fail). Existing pods keep running because kubelet uses local cache. Restore from snapshot, never from a single member.

### Q12. How big should etcd snapshots be and where stored?
Full DB plus 10% overhead. Store in object storage in two regions, encrypted, with daily lifecycle. Snapshot every 30 minutes for production.

### Q13. Stacked vs external etcd topology?
Stacked is simpler and cheaper, suitable up to 500 nodes. External etcd gives independent scaling and isolated failure domains, mandatory above 1000 nodes.

### Q14. How do you handle etcd compaction lag?
Set `--auto-compaction-mode=periodic --auto-compaction-retention=8h`. Without it the keyspace grows unbounded.

### Q15. What metric tells you etcd is the bottleneck?
`etcd_server_proposals_failed_total` increasing, `etcd_disk_backend_commit_duration_seconds` p99 above 25 ms, or `apiserver_request_duration_seconds` p99 above 1s for LIST.

### Q16. How do you safely add a fourth etcd member?
Add as learner first. Wait for it to catch up. Promote. Never jump from 3 to 5 in one step.

### Q17. Do you use etcd encryption at rest?
Yes. Use KMS provider with envelope encryption. Rotate KEK quarterly. Test decryption path during DR drills.

### Q18. What is the impact of large secrets on etcd?
Each Secret read pulls full payload through API server. Many large secrets in `LIST` operations balloon memory. Cap secret size to 256 KB.

## C. Control-Plane HA

### Q19. Minimum production control-plane topology?
Three API servers behind an L4 LB, three etcd members, two scheduler and two controller-manager replicas with leader election, spread across three AZs.

### Q20. Why three and not two control-plane nodes?
Two cannot form quorum if one fails. Three tolerates one failure. Five tolerates two but doubles write latency.

### Q21. How do you upgrade a control plane without downtime?
Upgrade etcd first (one member at a time). Then API servers (one at a time, drain LB). Then scheduler and controller-manager. Then nodes. Never skip minor versions.

### Q22. What does the API server LB need to do?
TCP passthrough on 6443. Health check `/livez`. Sticky-by-source-ip is fine but not required. SNI passthrough for kubelet client cert auth.

### Q23. How do you protect against API server overload?
APF (API Priority and Fairness) flow schemas. Dedicate priority levels for system-leader-election, node-high (kubelet), workload-low (CI bots).

## D. Scheduler Tuning at 5000 Nodes

### Q24. What is the default scheduler throughput?
About 100 pods per second on a tuned 5000-node cluster. Raw scoring is bounded by the number of nodes scored.

### Q25. How does percentageOfNodesToScore help?
Below this percentage of feasible nodes, scheduler stops scoring further. Default is adaptive (5% at 5000 nodes). Lower values trade quality for speed.

### Q26. When do you write a custom scheduler?
For batch workloads with gang scheduling (Volcano, Kueue), spot-aware bin packing, or topology-aware placement beyond what TopologySpreadConstraints offers.

### Q27. What is the difference between affinity and topology spread?
Affinity is hard or soft preference between pods. Topology spread enforces even distribution across a topology key with skew tolerance. Spread is the right primitive for HA.

### Q28. How do PodTopologySpreadConstraints scale?
O(pods x nodes) in worst case. At 5000 nodes with thousands of spread pods, scheduler latency spikes. Mitigate with `matchLabelKeys` and per-namespace selectors.

### Q29. How does the scheduler handle preemption?
Identifies victims with lower priority that, if removed, would let the pending pod fit. Adds a 30s grace nomination. Disable on tenant clusters to prevent noisy neighbors abusing priority.

### Q30. What is the cache invalidation cost on scheduler restart?
Full re-list of nodes and pods. At 5000 nodes this is multi-minute. Run two scheduler replicas with leader election and stagger restarts.

### Q31. How do you debug scheduler latency?
Enable scheduler `verbosity=4` briefly. Check `scheduler_e2e_scheduling_duration_seconds`. The PreFilter and Score plugins are usually the culprits — InterPodAffinity at scale is the worst offender.

## E. Pod Density Limits

### Q32. What is the theoretical pod-per-node limit?
110 pods per node default, raisable to 250 with kubelet `--max-pods`. Above 250, conntrack and IP exhaustion bite.

### Q33. What runs out first as you push density?
1. CIDR IPs (each pod needs one)
2. Conntrack entries
3. cgroup memory accounting overhead
4. PLEG relist time (kubelet performance)

### Q34. How do you budget node CPU for system overhead?
Reserve 100m + (10m per pod) for kubelet, plus 100m for kube-proxy, plus runtime overhead. On a 32-core node hosting 110 pods that is roughly 1.5 cores reserved.

### Q35. What is PLEG and why does it fail?
Pod Lifecycle Event Generator. Kubelet polls container runtime to detect state changes. With many pods or slow runtime it exceeds the 3-minute threshold and node goes NotReady.

### Q36. How does the IPv4 ENI limit affect AWS density?
Each EC2 instance type has a max ENI count and IPs per ENI. Use ENI prefix delegation or IPv6 to increase pod density on small nodes.

## F. Networking Choices

### Q37. Calico vs Cilium tradeoffs?
Calico: mature, simple BGP, iptables or eBPF dataplane, strong policy. Cilium: eBPF native, identity-based policy, Hubble observability, service mesh capabilities, steeper learning curve.

### Q38. When would you not use a CNI overlay?
When pods need real routable IPs (legacy firewall integration), when overlay encapsulation overhead matters (sub-microsecond latency), or in baremetal with BGP.

### Q39. What does kube-proxy do and what replaces it?
Implements Service VIP via iptables or IPVS. Cilium kube-proxy replacement uses eBPF for lower latency and no iptables churn. Required at high service counts.

### Q40. NetworkPolicy default-deny pattern?
Deploy a default-deny ingress and egress per namespace, then allow specific flows. Without default-deny, NetworkPolicy is additive-only and tenants can talk freely.

### Q41. When is NodePort acceptable?
Internal traffic, lab clusters. Production should use LoadBalancer or Ingress. NodePort exposes random high ports and complicates firewall rules.

### Q42. What is the cost of LoadBalancer-per-Service?
One cloud LB per Service. At 100 services that is 100 LBs. Use a single Ingress controller or Gateway API instead.

## G. Storage Tiering

### Q43. How do you tier storage for cost and performance?
Premium SSD (databases), standard SSD (logs and general), HDD (cold backups). Define StorageClasses per tier with `volumeBindingMode: WaitForFirstConsumer` for topology-aware provisioning.

### Q44. Static vs dynamic provisioning?
Dynamic for stateless and most stateful. Static for pre-existing volumes (legacy NFS shares, snapshot restores).

### Q45. What is the impact of `ReadWriteMany`?
Most block storage cannot do RWX. Forces NFS, CephFS, EFS, or cloud filesystems with higher latency. Avoid unless required.

### Q46. How do you do volume backups at scale?
Velero with CSI snapshots. Schedule per namespace. Test restore in a sandbox cluster monthly. Snapshots are not backups until restored.

### Q47. What happens when a PVC outgrows its PV?
With `allowVolumeExpansion: true` on the StorageClass, edit PVC `spec.resources.requests.storage`. CSI driver expands. Some filesystems require pod restart for online resize.

### Q48. How do you handle stuck PVCs after node deletion?
Force delete the VolumeAttachment, then the PVC. Cleanup orphaned cloud disks via cloud CLI. Automate via a controller for large clusters.

## H. Namespace Strategy

### Q49. Namespace per team or per app?
Per app for production, per team for dev. App-per-namespace gives clean RBAC and quota boundaries. Team-per-namespace simplifies dev sandbox cleanup.

### Q50. What belongs in a NamespaceTemplate?
ResourceQuota, LimitRange, default NetworkPolicy (deny-all), default ServiceAccount with minimal RBAC, image pull secret. Use Kyverno or HNC to apply.

### Q51. How do you handle cross-namespace references?
Avoid. Services can be referenced as `service.namespace.svc.cluster.local` but Secrets and ConfigMaps cannot cross namespaces. Use ExternalSecrets or replicate via controller.

### Q52. What is the pod count per namespace ceiling?
Soft ceiling around 5000 for kubectl usability. Hard ceiling is etcd size. Split namespaces when LIST takes more than 2 seconds.

## I. GitOps Adoption Tradeoffs

### Q53. Argo CD vs Flux?
Argo CD: UI-first, multi-tenancy via projects, application-of-applications pattern. Flux: CLI-first, GitOps Toolkit composable, Kustomize-native, OCI artifact support. Pick based on team UI preference.

### Q54. Push vs pull deployment?
Pull (GitOps) is the default. Cluster-internal agent reconciles from Git. Push (CI deploys) is simpler but exposes kubeconfig and breaks audit. Use push only for short-lived ephemeral envs.

### Q55. How do you handle secrets in GitOps?
SealedSecrets, External Secrets Operator with Vault/SM, or SOPS. Never plaintext in Git. Sealed secrets are cluster-scoped which complicates DR.

### Q56. App-of-apps vs ApplicationSet?
App-of-apps for static known set. ApplicationSet for templated dynamic generation (one app per cluster, per environment).

### Q57. How do you do progressive delivery with GitOps?
Argo Rollouts or Flagger sidecar to GitOps. The CRD lives in Git, the controller manages canary or blue-green steps.

### Q58. Drift detection and auto-heal — when do you disable?
Disable auto-heal during incident response so you can hotfix in-cluster. Re-enable after Git is updated. Always keep drift detection.

### Q59. What is the multi-cluster GitOps pattern?
Hub-and-spoke: one Argo CD or Flux instance manages many clusters via cluster registration. Or one instance per cluster for stronger blast radius isolation.

### Q60. How do you avoid Helm value drift?
Single source of truth: values.yaml in Git. PRs only. Use `helm diff` in CI. Block kubectl edit via RBAC for production namespaces.

## J. Bonus

### Q61. When do you split a cluster?
At etcd 4 GiB, 5000 nodes, or when blast radius of a single failure exceeds tolerated impact. Earlier if multi-region or regulatory.

### Q62. What is the right VPA + HPA combination?
VPA for memory (right-sizing), HPA for CPU and custom metrics. Never both on the same metric or they fight.

### Q63. Cluster autoscaler vs Karpenter?
CA: node-group based, slow (minutes). Karpenter: just-in-time provisioning, instance-type aware, faster, AWS-only mature support but expanding.

### Q64. How do you do zero-downtime cluster upgrades?
Blue-green clusters with traffic shift via DNS or Gateway. Or in-place rolling, draining nodes one AZ at a time, with PodDisruptionBudgets enforced.

### Q65. What is the single most important production safety net?
PodDisruptionBudget on every critical workload. Without it, a node drain can take down all replicas.

## End
