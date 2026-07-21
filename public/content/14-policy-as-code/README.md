# 14 · Policy as Code — OPA & Kyverno

<p class="hero policy-as-code"><h1>14 · Policy as Code — <em>OPA & Kyverno</em></h1><p class="tagline">Shift compliance left — enforce security, cost control, and governance as Kubernetes admission policies, not post-incident runbooks.</p></p>

## Roadmap — your learning path

<div class="roadmap" markdown>

<div class="stop" data-step="1" markdown>
#### What is Policy-as-Code?
Treat compliance rules like application code — versioned, tested, reviewed, deployed. Stop writing post-incident runbooks and start failing fast at admission time.
</div>

<div class="stop" data-step="2" markdown>
#### Rego Language Fundamentals
OPA's declarative, logic-based policy language. Learn packages, rules, input documents, `deny`, `allow`, and set comprehensions from zero.
</div>

<div class="stop" data-step="3" markdown>
#### OPA Gatekeeper
ConstraintTemplate + Constraint two-step model. Webhook installation, audit mode, enforcement actions: `deny` / `warn` / `dryrun`.
</div>

<div class="stop" data-step="4" markdown>
#### OPA Advanced Patterns
Complex Rego (joins, comprehensions, aggregates), mutation policies, Conftest in CI, OPA bundle distribution from S3.
</div>

<div class="stop" data-step="5" markdown>
#### Kyverno Basics
Native Kubernetes policies as CRDs — no Rego needed. Validate, Mutate, Generate, and VerifyImage policy types.
</div>

<div class="stop" data-step="6" markdown>
#### Kyverno Advanced
JMESPath context variables, `kyverno test` with test suites, PolicyExceptions, Chainsaw e2e testing framework.
</div>

<div class="stop" data-step="7" markdown>
#### Policy Testing
Unit test with `opa test`, integration test with `kyverno test`, pipeline gate with `conftest`. Test-driven policy development.
</div>

<div class="stop" data-step="8" markdown>
#### 10 Policy Projects
Baseline security suite, cost controls, naming conventions, network policy automation, image supply chain, multi-tenancy, compliance mapping, GitOps pipeline, custom webhook, governance framework.
</div>

</div>

---

## Architecture — how policies flow from Git to cluster

```mermaid
flowchart LR
  Dev["Developer\ngit commit"] --> PR["Pull Request"]
  PR --> CI["CI Pipeline\nconftest test\nopa test\nkyverno test"]
  CI -->|pass| Merge["Merge to main"]
  Merge --> CD["CD / GitOps\nFlux or ArgoCD"]
  CD --> Policies["ClusterPolicy CRDs\nor Gatekeeper Constraints\nin cluster"]
  
  subgraph "Admission Webhook (runtime)"
    Policies --> Webhook["Validating /\nMutating Webhook"]
    Webhook --> OPA["OPA Engine\n(Gatekeeper)"]
    Webhook --> Kyverno["Kyverno Engine"]
    OPA --> Decision["allow / deny / warn"]
    Kyverno --> Decision
  end

  Decision -->|deny| Rejected["Request rejected\n403 Forbidden"]
  Decision -->|allow| APIServer["K8s API Server\nObject stored in etcd"]

  subgraph "Continuous Audit"
    Audit["Audit Controller\nevery 60s"] --> Scan["Scan existing\nresources"]
    Scan --> Report["violations in\nstatus.violations"]
    Report --> Grafana["Grafana Dashboard\npolicy compliance %"]
  end
```

---

## OPA vs Kyverno — choose your weapon

| | OPA / Gatekeeper | Kyverno |
|---|---|---|
| **Policy language** | Rego (logic-based, Datalog-inspired) | YAML / JMESPath (K8s-native) |
| **Installation** | Helm chart, separate control plane | Helm chart, K8s-native CRDs |
| **Policy CRDs** | `ConstraintTemplate` + `Constraint` | `ClusterPolicy` / `Policy` |
| **Mutation** | `AssignImage`, `Assign`, `AssignMetadata` | `patchStrategicMerge`, `patchesJson6902` |
| **Image verification** | External (manual webhook) | Built-in `verifyImages` + cosign |
| **Resource generation** | Not natively supported | `generate` rule type built-in |
| **Testing** | `opa test`, `conftest` | `kyverno test`, Chainsaw |
| **Learning curve** | Steeper (Rego is unique) | Gentler (YAML-first) |
| **Ecosystem** | Gatekeeper Policy Library, Conftest | Kyverno Policy Library, Chainsaw |
| **Use when** | Complex cross-resource logic, multi-system (Terraform, Helm CI) | K8s-only, faster onboarding, image signing |

---

## Policy categories

| Category | Examples | Tool preference |
|---|---|---|
| **Security** | No privileged pods, no root containers, read-only root FS | Both — OPA for complexity |
| **Cost control** | Require CPU/memory limits, deny oversized requests | Kyverno (mutate defaults) |
| **Compliance** | CIS Benchmark controls, PCI-DSS, SOC2 controls | OPA (audit mode + reports) |
| **Networking** | Require NetworkPolicy, deny host networking | Kyverno (generate companion resources) |
| **Naming conventions** | Namespace pattern `<team>-<env>-<app>`, label taxonomy | Either |
| **Image supply chain** | Registry allowlist, no `:latest`, cosign signatures | Kyverno (verifyImages built-in) |
| **Multi-tenancy** | ResourceQuota per team, cross-namespace restrictions | Both |

---

## Module pages

| Page | Content |
|---|---|
| [01 — OPA Foundations](01-opa-foundations.md) | Rego language from zero, Gatekeeper install, ConstraintTemplate pattern, audit mode, testing |
| [02 — OPA Kubernetes](02-opa-kubernetes.md) | Policy library: required labels, resource limits, privileged prevention, registry allowlist, external data |
| [03 — OPA Advanced](03-opa-advanced.md) | Complex Rego, mutation, Conftest in CI, bundle server |
| [04 — Kyverno Foundations](04-kyverno-foundations.md) | Architecture, validate, mutate, generate, verifyImages |
| [05 — Kyverno Advanced](05-kyverno-advanced.md) | JMESPath, kyverno test, PolicyExceptions, Chainsaw |
| [06 — Policy Projects](06-policy-projects.md) | 10 hands-on projects from beginner to expert |
| [commands.md](commands.md) | Quick-reference command cheatsheet |
