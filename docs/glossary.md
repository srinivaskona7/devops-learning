---
title: Glossary
hide:
  - toc
---

# Glossary

A reference of common DevOps, Kubernetes, container, and platform terms used
throughout this site. Hover any abbreviation in the docs to see its definition
(when supported by the browser).

*[API]: Application Programming Interface — a contract for software-to-software communication.
*[CRD]: Custom Resource Definition — extends the Kubernetes API with user-defined object types.
*[CR]: Custom Resource — an instance of a CRD-defined object.
*[CNI]: Container Network Interface — pluggable pod networking spec (Calico, Cilium, Flannel).
*[CSI]: Container Storage Interface — pluggable storage driver spec for orchestrators.
*[CRI]: Container Runtime Interface — kubelet ↔ runtime contract (containerd, CRI-O).
*[OCI]: Open Container Initiative — image and runtime specs for containers.
*[Pod]: The smallest deployable unit in Kubernetes — one or more containers sharing network and storage.
*[ReplicaSet]: Ensures a specified number of pod replicas are running at any time.
*[Deployment]: Declarative manager of ReplicaSets that supports rolling updates and rollbacks.
*[StatefulSet]: Workload controller for stable network identity and persistent storage per replica.
*[DaemonSet]: Ensures a pod runs on every (or selected) node.
*[Job]: Run-to-completion workload that creates one or more pods.
*[CronJob]: Scheduled Job — runs on a cron-style schedule.
*[Service]: Stable virtual IP and DNS name fronting a set of pods.
*[Ingress]: HTTP(S) routing rules into the cluster, implemented by an Ingress controller.
*[Gateway API]: Successor to Ingress — role-oriented, expressive L4/L7 routing API.
*[ConfigMap]: Non-confidential configuration delivered to pods as env, args, or files.
*[Secret]: Sensitive data (tokens, keys) base64-encoded and mounted to pods.
*[PV]: PersistentVolume — a piece of cluster storage provisioned admin- or dynamically.
*[PVC]: PersistentVolumeClaim — a user request for storage that binds to a PV.
*[StorageClass]: Defines a "class" of storage and the provisioner used for dynamic PVs.
*[HPA]: Horizontal Pod Autoscaler — scales replicas on metrics like CPU or custom signals.
*[VPA]: Vertical Pod Autoscaler — recommends/sets pod resource requests.
*[KEDA]: Kubernetes Event-Driven Autoscaling — scales workloads from external event sources.
*[RBAC]: Role-Based Access Control — Kubernetes authorization model for users/SAs.
*[SA]: ServiceAccount — identity for processes that run in a pod.
*[NetworkPolicy]: Pod-to-pod L3/L4 firewall implemented by the CNI plugin.
*[PSA]: Pod Security Admission — namespace-level baseline/restricted/privileged enforcement.
*[OPA]: Open Policy Agent — general-purpose policy engine used by Gatekeeper.
*[Gatekeeper]: OPA-based admission controller for Kubernetes policy.
*[Kyverno]: Kubernetes-native policy engine (no Rego required).
*[etcd]: Distributed key-value store — the source of truth for the cluster state.
*[kubelet]: Node agent that runs pods via the CRI runtime.
*[kube-proxy]: Maintains network rules implementing Services on each node.
*[kube-apiserver]: Front door to the cluster — REST API for all components.
*[kube-scheduler]: Assigns pods to nodes based on constraints and resources.
*[controller-manager]: Runs core controllers (Deployment, Node, ServiceAccount, etc.).
*[Operator]: Custom controller that extends Kubernetes with domain knowledge.
*[Helm]: The package manager for Kubernetes — templates and releases.
*[Helm chart]: A packaged Helm application (templates + values + metadata).
*[release]: A deployed instance of a Helm chart in a cluster.
*[Kustomize]: Template-free YAML overlay tool, built into kubectl.
*[Argo CD]: GitOps continuous-delivery controller for Kubernetes.
*[Argo Rollouts]: Progressive delivery controller (canary, blue-green) for Kubernetes.
*[Flagger]: Progressive delivery operator integrating with service meshes.
*[Flux]: GitOps toolkit for Kubernetes by the CNCF.
*[GitOps]: Operational model where Git is the single source of truth for declarative infra.
*[sidecar]: Auxiliary container in the same pod (proxy, log shipper, etc.).
*[init container]: Container that runs to completion before main containers start.
*[OOMKill]: Out-Of-Memory kill — kernel terminates a process exceeding its memory limit.
*[CrashLoopBackOff]: Pod state where a container repeatedly crashes and restarts with backoff.
*[ImagePullBackOff]: Pod state where the container image cannot be pulled.
*[runc]: Low-level OCI runtime that actually creates the container (used by containerd).
*[containerd]: High-level container runtime — the default for most modern clusters.
*[CRI-O]: Lightweight OCI-compatible runtime built specifically for Kubernetes.
*[BuildKit]: Modern Docker image builder with parallelism, caching, and frontends.
*[distroless]: Minimal images with only the app and its runtime — no shell, no package manager.
*[scratch]: Empty base image — start from zero bytes.
*[multi-stage]: Dockerfile pattern using multiple FROM stages to keep final images small.
*[IRSA]: IAM Roles for Service Accounts — AWS pod-level cloud identity.
*[Workload Identity]: GCP equivalent of IRSA — bind GSAs to KSAs.
*[mTLS]: Mutual TLS — both client and server authenticate with certificates.
*[SPIFFE]: Secure Production Identity Framework For Everyone — universal workload identity spec.
*[SPIRE]: SPIFFE Runtime Environment — reference SPIFFE implementation.
*[Cosign]: Sigstore tool to sign, verify, and store container image signatures.
*[Sigstore]: Free signing and transparency log for software artifacts.
*[SLSA]: Supply-chain Levels for Software Artifacts — tiered build-integrity framework.
*[SBOM]: Software Bill Of Materials — inventory of components in an artifact.
*[CVE]: Common Vulnerabilities and Exposures — public vulnerability identifier.
*[Trivy]: Open-source vulnerability and misconfiguration scanner.
*[SLI]: Service Level Indicator — a measured metric (e.g. request success rate).
*[SLO]: Service Level Objective — target value for an SLI over a window.
*[SLA]: Service Level Agreement — contractual commitment with consequences.
*[Error budget]: 1 − SLO target — the allowed unreliability over a window.
*[Prometheus]: Time-series database and pull-based metrics collector.
*[Grafana]: Dashboards and visualisation for time-series data.
*[Loki]: Prometheus-style log aggregation system from Grafana Labs.
*[Tempo]: Distributed tracing backend from Grafana Labs.
*[OpenTelemetry]: Vendor-neutral observability data spec and SDK suite.
*[Service Mesh]: Sidecar-based L7 networking layer (Istio, Linkerd) for mTLS, traffic, telemetry.
*[Istio]: CNCF service mesh built on Envoy.
*[Linkerd]: Lightweight CNCF service mesh focused on simplicity.
*[Envoy]: High-performance L7 proxy used in many service meshes and gateways.
*[Terraform]: HashiCorp's declarative infrastructure-as-code tool.
*[OpenTofu]: Open-source fork of Terraform.
*[IaC]: Infrastructure as Code — managing infra via versioned declarative files.
*[CI]: Continuous Integration — automated build and test on every change.
*[CD]: Continuous Delivery / Deployment — automated release pipeline.
*[Blue/Green]: Deployment pattern with two parallel environments and instant cutover.
*[Canary]: Deployment pattern that routes a small % of traffic to a new version.
*[FinOps]: Cloud financial operations — cost transparency and accountability.
