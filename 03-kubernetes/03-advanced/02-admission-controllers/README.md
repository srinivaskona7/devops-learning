# 02 — Admission Controllers

Admission controllers intercept API requests **after authentication/authorization** but **before persistence**. They can mutate or validate.

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-02-admission-controllers-README-1-93d8b21f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-02-admission-controllers-README-1-93d8b21f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-02-admission-controllers-README-1-93d8b21f.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    Client[kubectl] --> Auth[AuthN/AuthZ]
    Auth --> Mut[Mutating Admission]
    Mut --> Schema[Schema Validation]
    Schema --> Val[Validating Admission]
    Val --> Etcd[(etcd)]
    Mut -.webhook.-> MW[MutatingWebhook]
    Val -.webhook.-> VW[ValidatingWebhook]
    Val -.in-process.-> VAP[ValidatingAdmissionPolicy CEL]
```

</details>

</details>

</details>

## Three flavors

| Type | Where it runs | Use |
|------|---------------|-----|
| Built-in (compiled) | inside kube-apiserver | NamespaceLifecycle, ResourceQuota, PodSecurity, etc |
| Webhook (Mutating/Validating) | external HTTPS service | Custom logic in any language |
| ValidatingAdmissionPolicy (CEL) | inside kube-apiserver, GA in 1.30 | Declarative validation, no webhook to operate |

## Mutating vs Validating
- Mutating runs first, can patch the object (defaults, sidecar injection).
- Validating runs after schema check, can only accept/reject.
- All mutating webhooks must be idempotent and run before all validating ones.

## Policy engines
| Engine | Language | Scope |
|--------|----------|-------|
| OPA Gatekeeper | Rego (ConstraintTemplate + Constraint) | Validation, audit |
| Kyverno | YAML-native policies | Validate / Mutate / Generate / VerifyImages |
| jsPolicy | JavaScript | Validate / Mutate |

For most teams Kyverno is the lowest-friction choice. Use Gatekeeper if you already have Rego skills or need OPA elsewhere.

## Files
- [kyverno-policy.yaml](kyverno-policy.yaml)
- [opa-constraint.yaml](opa-constraint.yaml)
