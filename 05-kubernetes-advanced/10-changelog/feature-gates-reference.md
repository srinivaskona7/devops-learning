# Feature Gates Reference (1.27 → 1.33)

A non-exhaustive table of important gates and their lifecycle. Always cross-reference the official feature-gates page before relying on a specific row.

Legend: A=alpha, B=beta, **G**=GA, R=removed, "—"=does not exist yet.

| Feature gate | 1.27 | 1.28 | 1.29 | 1.30 | 1.31 | 1.32 | 1.33 |
|--------------|------|------|------|------|------|------|------|
| SeccompDefault | **G** | G | G | G | G | G | G |
| JobMutableNodeSchedulingDirectives | **G** | G | G | G | G | G | G |
| ServerSideFieldValidation | **G** | G | G | G | G | G | G |
| OpenAPIV3 | **G** | G | G | G | G | G | G |
| DownwardAPIHugePages | **G** | G | G | G | G | G | G |
| SidecarContainers | — | A | **B (on)** | B | B | B | **G** |
| RetroactiveDefaultStorageClass | B | **G** | G | G | G | G | G |
| ValidatingAdmissionPolicy | A | **B (off)** | B | **G** | G | G | G |
| ReadWriteOncePod | B | B | **G** | G | G | G | G |
| KMSv2 / KMSv2KDF | A | B | **G** | G | G | G | G |
| APIPriorityAndFairness | B | B | **G** | G | G | G | G |
| AppArmorFields | — | — | A | **G** | G | G | G |
| StructuredAuthenticationConfiguration | — | A | A | **B** | B | B | B/G |
| MinDomainsInPodTopologySpread | B | B | B | **G** | G | G | G |
| PodDisruptionConditions | B | B | B | **G** | G | G | G |
| PersistentVolumeLastPhaseTransitionTime | A | B | B | B | **G** | G | G |
| NFTablesProxyMode | — | — | A | A | **B** | B | G (verify) |
| ServiceTrafficDistribution | — | — | — | A | **B** | B | G |
| AnonymousAuthConfigurableEndpoints | — | — | — | — | A | **B** | B/G |
| ConsistentListFromCache | — | A | A | B | B | **G** | G |
| StatefulSetStartOrdinal | A | B | B | B | B | **G** | G |
| DynamicResourceAllocation (structured) | — | — | A | A | A | **B (off)** | B |
| InPlacePodVerticalScaling | A | A | A | B | B | B | **B (on)** |
| UserNamespacesSupport | A | A | A | B | B | B | **G** |
| MultiCIDRServiceAllocator | A | A | A | B | B | B | **G** |
| PodLifecycleSleepAction | — | — | A | B | B | B | **G** |
| WatchList | — | — | A | B | B | B | B/G |

> Where a cell shows the maturity transition in **bold**, that is when it changed in that release. Cells marked "G (verify)" should be cross-checked against the official feature-gates documentation before relying on them.
