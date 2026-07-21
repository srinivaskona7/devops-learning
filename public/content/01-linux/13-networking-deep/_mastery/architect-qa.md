# Architect Q&A — Networking Across Linux, K8s, and Cloud

50+ production-grade questions. Each answer is concise but complete enough to
defend in a design review. Optimize for judgment, not memorization.

---

## CNI Selection at Scale

### Q1. How do you choose a CNI for a 500-node cluster?

Decision axes: dataplane (iptables vs IPVS vs eBPF), encapsulation (VXLAN,
Geneve, none), policy (L3/L4 vs L7), IPAM model (per-node CIDR vs cloud
ENI), and operability (CRDs, observability, upgrade story). At 500 nodes,
iptables-based dataplanes degrade non-linearly. Choose Cilium (eBPF) or
Calico in eBPF mode. AWS VPC CNI is fine if pod density per node is low
and you need real VPC IPs for flow logs and security groups.

### Q2. When does AWS VPC CNI break down?

Pod density limits per instance type (ENI * IPs-per-ENI). m5.large gives
roughly 29 pods. Custom networking and prefix delegation help, but you pay
in IPv4 exhaustion in the VPC. At 100+ pods/node, switch to Cilium with
ENI mode or use IPv6 prefix delegation.

### Q3. Calico vs Cilium tradeoff in one paragraph.

Calico is mature, simple, BGP-native, and the default for many on-prem
deployments. Cilium gives eBPF observability, kube-proxy replacement,
ClusterMesh, L7 policy, and Hubble visibility, but has higher operational
complexity and kernel version requirements. Pick Calico for stability and
BGP integration; Cilium for observability and L7 features.

### Q4. Flannel — when is it still defensible?

Edge clusters, dev clusters, and learning environments. Anywhere you need
"just works" with VXLAN and no policy. Production multi-tenant: no.

---

## eBPF Dataplane Tradeoffs

### Q5. Why does eBPF beat iptables at scale?

iptables is a linear chain. 10k services means 10k * N rules evaluated per
packet. eBPF uses hash maps for O(1) service lookup, runs in-kernel without
netfilter overhead, and bypasses conntrack for known flows. Latency drops,
CPU drops, p99 stabilizes.

### Q6. What breaks when you enable Cilium kube-proxy replacement?

Anything that read iptables NAT tables for debugging stops working. Some
service mesh sidecars expecting iptables redirection need Cilium-aware
chaining. Conntrack visibility shifts to `cilium bpf ct list`. NodePort
source IP preservation behavior changes; verify externalTrafficPolicy.

### Q7. Kernel version requirements for production eBPF?

Minimum 5.4 for basics, 5.10+ for full Cilium feature set (BIG TCP,
bandwidth manager, SOCK_OPS), 5.15+ for stable XDP redirects. RHEL 8
backports help but are uneven. Validate with `cilium status --verbose`.

### Q8. eBPF observability tools you actually run?

`cilium monitor --type drop`, `hubble observe --verdict DROPPED`,
`bpftool prog show`, `bpftrace` one-liners for kprobe tracing. For SRE
on-call: Hubble UI plus Grafana with Cilium metrics.

### Q9. Risks of running eBPF programs in production?

Kernel panic from buggy programs (rare with verifier), upgrade pain when
kernel ABI shifts, debugging requires bcc/bpftrace skill, and limited
support from non-Cilium vendors. Mitigate with canary nodes and pinned
kernel versions.

---

## DNS at Scale

### Q10. NodeLocal DNSCache — when do you roll it out?

Roll out when CoreDNS shows >10k qps cluster-wide, or when you see
intermittent 5s timeouts due to conntrack races on UDP. NodeLocal eliminates
the race by serving DNS over a stable interface with no NAT.

### Q11. NodeLocal DNSCache rollout pitfalls?

Search domain expansion: the cache must respect `ndots:5` and rewrite
upstream queries correctly. Custom resolvers (e.g. corporate AD) need
explicit upstream stanzas. Pod DNSPolicy must remain ClusterFirst — if
you use Default, you bypass the cache. iptables/IPVS rules for the
169.254.20.10 link-local address must survive node reboots.

### Q12. Why do you see 5s DNS timeouts in K8s?

Conntrack race on UDP DNS in iptables NAT: two parallel queries from one
pod can race, one entry is dropped, retry waits for the 5s default timeout.
Fix: NodeLocal DNSCache (TCP to upstream), or single-request-reopen in
resolv.conf, or move to eBPF dataplane.

### Q13. How do you scale CoreDNS itself?

HPA on CPU plus a floor of 2 replicas per AZ. Autopath plugin to reduce
search domain expansion. Disable unnecessary plugins. Cache TTLs aligned
with workload tolerance. For very large clusters, use cluster-proportional
autoscaler keyed on node count.

### Q14. CoreDNS vs external DNS for service discovery?

CoreDNS for in-cluster. ExternalDNS controller publishes Ingress/Service
hostnames to Route53/Cloud DNS. Never proxy in-cluster lookups through an
external resolver — latency and cost explode.

---

## Service Mesh vs CNI L7

### Q15. CNI L7 policy or service mesh — how do you decide?

CNI L7 (Cilium) is sufficient if you need per-method HTTP authorization
and basic identity (SPIFFE). Add a service mesh when you need: rich traffic
shifting (canary, mirror), retries with budget, circuit breaking, mTLS
across multi-cluster, and an Envoy-grade L7 observability story.

### Q16. What does a service mesh actually cost?

Sidecar CPU and memory per pod (50-200m CPU, 100-300Mi RAM is realistic),
2-5ms p50 latency added per hop, control plane complexity (cert rotation,
config push), and extra failure modes (sidecar crash, config drift).
Budget for it in capacity planning.

### Q17. Sidecar vs ambient mesh tradeoff?

Sidecar: strong isolation per pod, mature, well-understood. Ambient
(Istio ztunnel + waypoint): lower per-pod overhead, simpler upgrades,
but newer with fewer escape hatches. Choose ambient for greenfield
medium-density clusters; sidecar for legacy and compliance-heavy.

### Q18. mTLS everywhere — is it always worth it?

Yes for multi-tenant or zero-trust requirements. No if you have a single
trust domain with strong network policy and the perf cost matters. mTLS
adds CPU (1-5%) and breaks L4 load balancers that need to peek at HTTP.

### Q19. How do you debug a 503 from Envoy?

`istioctl proxy-config cluster <pod>` and `listener` and `route`. Check
upstream cluster health, verify endpoints exist, confirm DestinationRule
TLS settings match the upstream. `istioctl analyze` for config conflicts.
Hubble or Envoy access logs with `%RESPONSE_FLAGS%` to identify UH, UF,
NR, etc.

---

## Multi-Cluster Connectivity

### Q20. What are the multi-cluster patterns?

(a) Submariner or Cilium ClusterMesh: pod IPs reachable across clusters.
(b) Istio multi-primary: mesh spans clusters with east-west gateways.
(c) Skupper or Linkerd multi-cluster: app-layer connections.
(d) Service-of-services: gateway exposes one cluster's services to another.

Pick (a) for stateful workload migration, (b) for full mesh features
across clusters, (c) for app-team-driven federation, (d) for simple cases.

### Q21. ClusterMesh requirements?

Non-overlapping pod CIDRs across all clusters, shared CA for identity,
control plane connectivity (etcd or KVStore), and matching Cilium versions.
Network reachability between node IPs across clusters (peering/VPN).

### Q22. East-west gateway in Istio multi-primary?

A gateway pod per cluster terminating SNI-routed mTLS for cross-cluster
traffic. Service entries in each cluster point to the remote gateway by
hostname. Identity is preserved via SPIFFE. Failure mode: gateway pod
becomes a chokepoint, scale and HPA carefully.

### Q23. How do you test cross-cluster connectivity?

`kubectl exec` from pod in cluster A, `curl` to FQDN in cluster B.
Inspect Envoy access logs in both clusters, run `cilium connectivity test
--multi-cluster`, watch Hubble for cross-cluster flows. Validate failover
by draining endpoints in one cluster.

---

## Hybrid Cloud Transit

### Q24. AWS Transit Gateway vs VPC Peering at scale?

Peering is point-to-point and N^2. TGW is hub-and-spoke with one route
table by default, supports thousands of attachments, gives transitive
routing and VPN/Direct Connect convergence. Above 5-10 VPCs, TGW always
wins. Cost: per-attachment-hour plus per-GB.

### Q25. Hybrid networking baseline pattern?

On-prem ↔ Direct Connect / ExpressRoute / Interconnect with BGP, terminate
on a transit hub (TGW, vWAN, Cloud Router), spokes are workload VPCs.
Backup tunnel: site-to-site IPSec VPN over public internet with BGP
failover. Test failover quarterly.

### Q26. Asymmetric routing in hybrid — root cause and fix?

Often: traffic egresses via cloud NAT, returns via on-prem firewall that
drops it as unsolicited. Fix: ensure stateful firewalls see both
directions, use route-based VPNs, anchor return path with policy routing
or BGP communities.

### Q27. DNS in hybrid?

Conditional forwarding: cloud Route53 Resolver inbound and outbound
endpoints, on-prem DNS forwards corp.local to on-prem AD, and
cloud-internal zones to Route53 outbound. Avoid public DNS round trips
for internal names.

---

## IPv6 and Dual Stack

### Q28. IPv6 dual-stack in K8s — when and how?

When: IPv4 exhaustion in pod CIDR or VPC, regulatory mandate, edge
networking. How: dual-stack from cluster bring-up (post-hoc is painful),
choose CNI that supports it (Cilium, Calico, AWS VPC CNI), pick
ipFamilyPolicy per Service (PreferDualStack or RequireDualStack).

### Q29. IPv6-only cluster — viable?

Viable in greenfield with NAT64/DNS64 for IPv4 reachability to the
internet and legacy services. AWS supports IPv6-only EKS. Operational
load: every workload must be IPv6-clean (no hardcoded IPv4 logic).

### Q30. Pod CIDR sizing math?

Per-node CIDR /24 gives 256 IPs which limits pods/node. Cluster /16 gives
256 nodes worth. For 1000 nodes, plan a /14 cluster CIDR plus pod density
math. Reserve room for blue/green node groups.

---

## MTU Strategy

### Q31. MTU 1500 vs 9001 vs 8950?

1500: safe everywhere, internet default. 9001: AWS jumbo, intra-VPC only.
8950 is a common pod MTU when overlaying VXLAN (1500 - 50 overhead)
or 8950 = 9001 - VXLAN headers. Mismatch causes silent throughput
collapse and PMTU black holes.

### Q32. How do you debug MTU issues?

`ping -M do -s <size>` to find black hole. `tracepath` shows PMTU drops.
`ip link show` for interface MTU. Look for ICMP "fragmentation needed"
being dropped by overzealous firewalls — the most common culprit.

### Q33. PMTUD blackhole mitigation?

Allow ICMP type 3 code 4 through all firewalls. Or set TCP MSS clamping
on tunnel endpoints (`iptables -t mangle ... TCPMSS --clamp-mss-to-pmtu`).
Or lower interface MTU below the bottleneck and accept the throughput hit.

---

## BGP and Top-of-Rack

### Q34. BGP unnumbered for ToR — why?

Eliminates per-link IPv4 management. Uses IPv6 link-local for the BGP
session. Reduces config sprawl in spine-leaf fabrics. Supported by
FRR, Cumulus, SONiC. Pairs naturally with Calico BGP mode for
on-prem K8s.

### Q35. Calico BGP peering models?

Full mesh (small clusters, < 50 nodes), Route Reflector (medium),
ToR-as-RR (large, integrates with fabric), per-rack peering with node
selectors (very large). Production at scale: ToR-as-RR with BGP
unnumbered.

### Q36. ECMP with K8s — gotcha?

Per-flow hashing means a single connection cannot exceed one path's
bandwidth. Resilient hashing (consistent hash) avoids reshuffling all
flows on next-hop change. Without it, a node failure causes mass
rebalancing and conntrack churn.

---

## Conntrack and NAT

### Q37. Conntrack table sizing?

Default `nf_conntrack_max` is too low for busy nodes. Set to
`hashsize * 4` and align hashsize to expected concurrent connections.
Watch `nf_conntrack_count` and entries dropped (`/proc/net/stat/nf_conntrack`).
Tune `tcp_timeout_*` for short-lived flows.

### Q38. SNAT exhaustion in NAT gateway?

55k ephemeral ports per source IP per destination tuple. Egress to
the same destination from many pods through one NAT IP exhausts ports.
Fix: multiple NAT IPs, EIPs per AZ, or VPC endpoints to bypass NAT for
AWS service traffic.

### Q39. hostNetwork pods and conntrack?

Bypass pod network namespace, hit host conntrack directly. Useful for
DNS, ingress controllers, and high-throughput proxies. Cost: port
collision risk on the host.

---

## Load Balancing

### Q40. NodePort vs LoadBalancer vs Ingress?

NodePort: dev or behind external LB, port 30000-32767, no source IP
unless externalTrafficPolicy=Local. LoadBalancer: cloud LB per Service,
expensive at scale. Ingress / Gateway: one LB front, host/path routing
to many Services. Use Gateway API for new designs.

### Q41. externalTrafficPolicy Cluster vs Local?

Cluster: SNATs, hides client IP, balances across all pods regardless of
node. Local: preserves source IP, only routes to pods on the receiving
node, requires healthy pod presence on every backed node or you get
black holes. Use Local with anti-affinity and HPA tuning.

### Q42. Topology-aware routing?

Service `topologyAwareHints` keep traffic in the same zone. Saves
cross-AZ data transfer cost and latency. Risk: small zones get hotspots.
Validate endpoint distribution before enabling.

### Q43. Global LB strategy — Anycast or GeoDNS?

Anycast (BGP): instant failover, single VIP, requires global ASN and
peering. GeoDNS: simpler, slower failover (TTL bound), works with any
provider. Cloud equivalents: Global Accelerator, Cloud Load Balancing,
Front Door.

---

## Network Policy

### Q44. NetworkPolicy default-deny pattern?

Apply default-deny ingress and egress per namespace, then explicitly
allow. Egress policies must allow DNS to kube-system. Test with a debug
pod and `nc`. Use AdminNetworkPolicy for cluster-wide baselines.

### Q45. L7 policy use cases?

Allow GET but not POST on a metrics endpoint. Restrict gRPC method per
service identity. Filter by JWT claim. Tools: Cilium L7, Istio
AuthorizationPolicy. Don't over-policy — operational debugging gets
hard fast.

### Q46. NetworkPolicy doesn't take effect — debug steps?

Confirm CNI supports NetworkPolicy (Flannel does not by default). Check
namespace label selectors. Test with `kubectl exec ... nc -zv <target>`.
Inspect CNI policy logs (`cilium policy get`, `calicoctl get np`).
Verify pod has the label the policy expects.

---

## Observability

### Q47. What metrics matter for K8s networking?

CoreDNS qps and latency, conntrack count and drops, kube-proxy sync
duration, CNI program install errors, NodePort-to-pod latency, p99 of
Service VIP DNS resolution, NetworkPolicy drop counts.

### Q48. tcpdump on a pod — how?

`kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>`
shares the network namespace. Or `nsenter -t $(crictl inspect -o
go-template ...) -n tcpdump -i any`. For eBPF dataplanes, prefer
`hubble observe` or `cilium monitor`.

### Q49. How do you capture packets without losing them at 10Gbps?

`tcpdump -w` to ramdisk or NVMe with `-B` ring buffer tuned. For sustained,
use `dpdk` or AF_XDP-based capture (e.g., suricata). Don't capture on the
hot path in production — mirror via SPAN port to a dedicated sniffer.

---

## Failure Modes

### Q50. CoreDNS pod crash — blast radius?

If you have 2 replicas in one AZ, an AZ outage takes both out. Pods see
DNS timeouts, then 5s waits, then app errors. Fix: spread replicas across
AZs, use NodeLocal DNSCache, set anti-affinity.

### Q51. CNI controller down — what still works?

Existing pods keep networking via the dataplane. New pods stuck in
ContainerCreating. Service VIPs may stale. Don't deploy during a CNI
outage. SLO: CNI controller availability separate from data plane SLO.

### Q52. kube-proxy crash — impact?

Without kube-proxy replacement, Services break for new connections;
existing connections persist via conntrack until close. With Cilium
kube-proxy replacement, no kube-proxy to crash — risk shifts to the
Cilium agent.

### Q53. NAT gateway failure — what fails?

Outbound internet from private subnets stops. In-cluster traffic continues.
ECR pulls fail. CRD webhooks calling external services fail. Always
multi-AZ NAT, monitor active flows, and have a runbook.

---

## Design Tradeoffs

### Q54. Overlay vs underlay — when to choose which?

Overlay (VXLAN, Geneve): portable across networks, decoupled from
underlay, costs CPU and obscures debugging. Underlay (BGP, AWS VPC CNI,
Azure CNI): native VPC routing, no encap overhead, tied to cloud
constraints. Cloud production: underlay. Multi-cloud or on-prem with
mixed fabrics: overlay.

### Q55. When do you need a dedicated egress gateway?

Compliance (egress through inspected path), static egress IPs for
allowlists, central logging, DLP. Implement with egress-gateway pods,
Cilium egress IP, or cloud NAT with route table tricks.

### Q56. Sidecar proxy for egress vs cluster egress gateway?

Sidecar gives per-app identity at egress. Egress gateway centralizes but
loses per-app identity unless mTLS-in-mTLS is used. Combine: mesh sidecar
for identity, gateway for egress IP allowlisting.

### Q57. Kube-proxy IPVS vs iptables vs eBPF?

iptables: default, fine to a few thousand services. IPVS: scales linearly
with services, hash-based, kernel module. eBPF (Cilium kube-proxy
replacement): best at scale, additional operability story. Pick by scale
and team familiarity.

### Q58. How do you size a network design for unknown future scale?

Dual-stack from day one. Pick a CNI with eBPF future. Use Gateway API,
not legacy Ingress. Reserve large CIDRs. Standardize on one mesh or none.
Document the upgrade path. Run a chaos day that severs every cross-AZ
link.

---

## Last Word

Every answer here is debatable in context. The architect's job is not to
recite the answer but to ask the next question: what does the workload
actually need, what is the failure mode, and how do we observe it?
