---
hide:
  - toc
---

# 09 — Interview Prep

<div class="hero hero--interview" markdown>

## From "I've used it" to "I can defend every line."

Six focused tracks for senior platform and SRE interviews: kernel-level Linux, container internals, Kubernetes guts, distributed system design, real-world troubleshooting drills, and a curated question bank with model answers. Built for the engineer who wants to walk in and own the room.

[Start the labs](#start) · [Quick reference](#quick-reference) · [Pickup state](#pickup)

</div>

## :material-map-marker-path: Roadmap

<!-- mermaid:rendered -->
<p align="center"><img src="../assets/diagrams/docs-interview-prep-1-bc7e2aa2.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    A[01 Linux Internals] --> B[02 Container Internals]
    B --> C[03 Kubernetes Internals]
    C --> D[04 System Design]
    D --> E[05 Troubleshooting]
    E --> F[06 Questions Bank]
    classDef ip fill:#eef2ff,stroke:#6366f1,color:#1f2330,rx:8,ry:8;
    class A,B,C,D,E,F ip;
```

</details>

## :material-grid: Modules { #start }

<div class="grid cards" markdown>

-   :material-penguin:{ .lg .middle } **01 — Linux Internals**

    ---

    Process lifecycle, memory model, schedulers, syscalls, cgroups v2, namespaces.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/01-linux-internals/README.md)

-   :material-package-variant-closed:{ .lg .middle } **02 — Container Internals**

    ---

    OCI spec, runc, image layers, overlayfs, network namespaces, rootless.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/02-container-internals/README.md)

-   :material-kubernetes:{ .lg .middle } **03 — Kubernetes Internals**

    ---

    Control plane flow, scheduler, kubelet, CNI, CSI, controllers, etcd.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/03-kubernetes-internals/README.md)

-   :material-vector-arrange-below:{ .lg .middle } **04 — System Design**

    ---

    Multi-tenant platform, global LB, queue-backed pipelines, capacity math.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/04-system-design/README.md)

-   :material-fire-extinguisher:{ .lg .middle } **05 — Troubleshooting Scenarios**

    ---

    CrashLoopBackOff, OOMKilled, slow DNS, certificate expiry, split-brain.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/05-troubleshooting-scenarios/README.md)

-   :material-help-rhombus:{ .lg .middle } **06 — Questions Bank**

    ---

    Curated 200+ Q&A across Linux, K8s, networking, security, system design.

    [:octicons-arrow-right-24: Open module](../09-interview-prep/06-questions-bank/README.md)

</div>

## :material-flash: Quick reference { #quick-reference }

=== ":material-penguin: Linux"

    ```bash
    strace -f -e trace=network -p $(pgrep nginx)
    perf top -p $(pgrep app)
    cat /proc/$(pgrep app)/status | grep -E 'Vm|Threads'
    ```

=== ":material-kubernetes: K8s debug"

    ```bash
    kubectl get events --sort-by=.lastTimestamp -A | tail -20
    kubectl describe pod $POD | sed -n '/Events/,$p'
    kubectl debug -it $POD --image=nicolaka/netshoot --target=app
    ```

=== ":material-vector-arrange-below: Design"

    ```text
    Capacity:  RPS x payload x replication = bytes/s
    Latency:   p50 < p95 < p99; budget: 200ms p99
    HA:        N+2 across 3 AZs; quorum writes
    Backpressure: queue depth > threshold => shed load
    ```

=== ":material-fire-extinguisher: Triage"

    ```text
    1. What changed? (deploy, config, traffic)
    2. Blast radius? (one pod, one node, one region)
    3. SLI impact? (error rate, latency, saturation)
    4. Mitigate first, RCA after
    ```

## :material-bookmark-outline: Pickup state { #pickup }

Every subfolder ships a `commands.md`. Drop in, scan, continue.

## :material-link: Cross-references

- Earlier: [08 — Projects](08-projects.md) (your portfolio of stories)
- Next: Mock interviews — pair-program one project end-to-end out loud
- Deep dive: [03 — Kubernetes](03-kubernetes.md), [05 — Monitoring](05-monitoring.md), [06 — Security](06-security.md)
