# 01 — Helm Concepts

## Core Vocabulary

| Term | What it is |
|---|---|
| **Chart** | A package — directory of templates + metadata. The "recipe". |
| **Release** | A running instance of a chart in a cluster. Same chart → many releases. |
| **Repository** | Hosted index of charts (HTTP or OCI). |
| **Values** | Configuration injected into templates (`values.yaml`, `--set`, `-f`). |
| **Template** | Go-templated YAML that renders into K8s manifests. |
| **Revision** | Each `helm install/upgrade` increments a revision number. |
| **Hook** | Annotated manifest run at lifecycle events (pre-install, etc.). |

## Release Lifecycle

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/04-helm-01-concepts-README-1-28c40233.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant U as User
    participant H as Helm CLI
    participant K as Kube API
    participant S as Release Secret

    U->>H: helm install demo ./chart
    H->>H: Render templates + values
    H->>K: Apply manifests
    K-->>H: OK
    H->>S: Store revision 1
    U->>H: helm upgrade demo ./chart --set image.tag=v2
    H->>K: Apply diff
    H->>S: Store revision 2
    U->>H: helm rollback demo 1
    H->>S: Read revision 1
    H->>K: Re-apply revision 1 manifests
    H->>S: Store revision 3 (= rev 1 content)
    U->>H: helm uninstall demo
    H->>K: Delete manifests
    H->>S: Purge revisions
```

</details>
## Helm 3 vs Helm 2

| Aspect | Helm 2 | Helm 3 |
|---|---|---|
| Server component | **Tiller** (cluster-wide RBAC) | None (client only) |
| Release storage | ConfigMap in `kube-system` | `Secret` in release namespace |
| Release scope | Global names | Namespaced |
| 3-way merge | No | Yes |
| Library charts | No | Yes |
| OCI registry | No | Yes (default) |
| CRDs | Templates | `crds/` directory, install-only |
| Security | Tiller = god mode | User RBAC only |

> Helm 2 reached EOL in Nov 2020. Always use Helm 3.

## Mental Model

```text
Chart (recipe) + Values (ingredients) → Manifests → Release (running dish)
```

Same chart + different values = different releases (e.g. `nginx-dev`, `nginx-prod`).
