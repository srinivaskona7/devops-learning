---
title: DevOps Learning Lab
description: A hands-on, opinionated curriculum for senior platform engineers — Linux, Docker, Kubernetes, Helm, Observability, Security, Terraform, and end-to-end projects.
hide:
  - navigation
  - toc
---

<div class="hero hero--main" markdown>

# DevOps Learning Lab

<p class="tagline">A hands-on, opinionated curriculum for engineers who want to <strong>operate production systems</strong> — not just talk about them. Eight modules. Real labs. Interview-ready.</p>

<a class="cta primary" href="01-linux/README.md">:material-rocket-launch-outline: Start at Linux</a>
<a class="cta secondary" href="#folders">:material-map-outline: Browse topics</a>

</div>

## :material-lightbulb-on-outline: Why this repo

<div class="grid cards" markdown>

-   :material-source-repository:{ .lg .middle } **Open source, opinionated**

    ---

    Every lab is reproducible on a laptop or a real cluster. No vendor lock-in, no "it works on my SaaS."

-   :material-account-tie:{ .lg .middle } **Interview prep wired in**

    ---

    Every module ends with internals, gotchas, and a Q&A bank. Walk into senior interviews with stories, not slides.

-   :material-progress-check:{ .lg .middle } **Production patterns by default**

    ---

    RBAC, network policies, SLOs, supply-chain provenance — all wired in from module one. Not a bolt-on.

</div>

## :material-timeline-clock-outline: Learning path

<!-- mermaid:rendered -->
<p align="center"><img src="../assets/diagrams/docs-index-1-e731f913.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    A([01 Linux]) --> B([02 Docker])
    B --> C([03 Kubernetes])
    C --> D([04 Helm])
    D --> E([05 Monitoring])
    E --> F([06 Security])
    F --> G([07 Terraform])
    G --> H([08 Projects])
    H --> I([09 Interview Prep])
    classDef base fill:#eef2ff,stroke:#6366f1,color:#1f2330,rx:10,ry:10;
    classDef cap  fill:#ecfdf5,stroke:#10b981,color:#1f2330,rx:10,ry:10;
    class A,B,C,D,E,F,G base;
    class H,I cap;
```

</details>

## :material-folder-multiple-outline: Browse modules { #folders }

<div class="grid cards" markdown>

- [:material-console:{ .lg } **01 — Linux**](01-linux.md) <br/> Filesystem, users, processes, networking, systemd, troubleshooting.
- [:material-docker:{ .lg } **02 — Docker**](02-docker.md) <br/> Images, volumes, compose, BuildKit, registries, hardening.
- [:material-kubernetes:{ .lg } **03 — Kubernetes**](03-kubernetes.md) <br/> Core resources, deployment strategies, advanced controllers.
- [:material-ship-wheel:{ .lg } **04 — Helm**](04-helm.md) <br/> Templating, values, hooks, dependencies, ArgoCD integration.
- [:material-chart-line:{ .lg } **05 — Monitoring**](05-monitoring.md) <br/> Prometheus, Grafana, Loki, Tempo, OTel, SLOs, cost.
- [:material-shield-lock-outline:{ .lg } **06 — Security**](06-security.md) <br/> RBAC, PSA, network policies, supply chain, zero trust.
- [:material-cloud-cog-outline:{ .lg } **07 — Terraform**](07-terraform.md) <br/> Modules, state, workspaces, AWS/GCP/K8s providers.
- [:material-flag-checkered:{ .lg } **08 — Projects**](08-projects.md) <br/> End-to-end labs from hello-world to multi-region prod.
- [:material-account-tie:{ .lg } **09 — Interview Prep**](interview-prep.md) <br/> Internals, system design, troubleshooting drills, Q&A bank.

</div>

## :material-account-group-outline: By role

<div class="grid cards" markdown>

-   :material-seedling:{ .lg .middle } **Beginner**

    ---

    New to ops? Start with **Linux**, then **Docker** basics, then ship the [hello-world end-to-end](08-projects.md) project.

    [:octicons-arrow-right-24: Beginner path](01-linux.md)

-   :material-server-network:{ .lg .middle } **Platform Engineer**

    ---

    Already shipping? Jump to **Kubernetes**, **Helm**, **Terraform**, then [GitOps with ArgoCD](08-projects.md).

    [:octicons-arrow-right-24: Platform path](03-kubernetes.md)

-   :material-clipboard-text-search-outline:{ .lg .middle } **SRE — interview prep**

    ---

    Targeted drill on internals, troubleshooting, system design, and a curated Q&A bank.

    [:octicons-arrow-right-24: Interview prep](interview-prep.md)

</div>

## :material-tools: Tools you'll master

<div class="tool-grid" markdown>
<a class="tool" href="01-linux.md"><span class="badge">:material-console:</span>Linux</a>
<a class="tool" href="02-docker.md"><span class="badge">:material-docker:</span>Docker</a>
<a class="tool" href="03-kubernetes.md"><span class="badge">:material-kubernetes:</span>Kubernetes</a>
<a class="tool" href="04-helm.md"><span class="badge">:material-ship-wheel:</span>Helm</a>
<a class="tool" href="05-monitoring.md"><span class="badge">:material-fire:</span>Prometheus</a>
<a class="tool" href="05-monitoring.md"><span class="badge">:material-chart-areaspline:</span>Grafana</a>
<a class="tool" href="05-monitoring.md"><span class="badge">:material-vector-polyline:</span>OpenTelemetry</a>
<a class="tool" href="06-security.md"><span class="badge">:material-shield-lock-outline:</span>OPA / Kyverno</a>
<a class="tool" href="06-security.md"><span class="badge">:material-certificate:</span>Cosign</a>
<a class="tool" href="07-terraform.md"><span class="badge">:material-cloud-cog-outline:</span>Terraform</a>
<a class="tool" href="08-projects.md"><span class="badge">:material-source-branch-sync:</span>ArgoCD</a>
<a class="tool" href="08-projects.md"><span class="badge">:material-progress-upload:</span>Argo Rollouts</a>
</div>

!!! tip "Local docs build"
    ```bash
    pip install -r requirements.txt
    mkdocs serve   # http://localhost:8000
    ```
