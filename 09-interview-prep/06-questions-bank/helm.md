# Helm Q&A Bank

These questions are the ones I've actually been asked / would ask. Helm shows up in any platform/SRE role where you ship apps to Kubernetes — interviewers want to see you understand templating, releases, and the operational sharp edges.

## How to use

Say each answer out loud, 60-second ceiling. Be ready to whiteboard a chart structure or explain how upgrades fail.

---

## Charts & Templates

**Q1. What is a Helm chart?**
A package of Kubernetes manifests with templating and metadata. Directory containing `Chart.yaml` (metadata), `values.yaml` (defaults), `templates/` (Go-templated YAML), optional `charts/` (subcharts). Distributed via repos as a tarball.

**Q2. What's in Chart.yaml?**
apiVersion (v2 for Helm 3), name, version (chart SemVer), appVersion (app version, free-form), description, type (application or library), dependencies, maintainers. version != appVersion — chart can iterate without app changing.

**Q3. What is a release?**
An instance of a chart deployed to a cluster. Same chart can be installed many times (different release names). Helm tracks release history in Secrets in the release namespace by default.

**Q4. Difference between values.yaml and --set?**
`values.yaml` is the chart's defaults. `-f myvalues.yaml` overrides them. `--set key=val` overrides via CLI (highest precedence). Multiple `-f` files merge in order. Use files for prod, `--set` for one-offs.

**Q5. How do Helm template functions work?**
Standard Go template + Sprig functions + Helm-specific (include, required, tpl, lookup). Common: `{{ .Values.replicas | default 1 }}`, `{{ include "app.fullname" . }}`, `{{ required "image required" .Values.image }}`.

**Q6. What is _helpers.tpl?**
Conventional file for named template definitions ({{- define "app.name" -}}...{{- end -}}). Reused across templates via `{{ include "app.name" . }}`. Keeps boilerplate (labels, names) DRY.

**Q7. include vs template?**
Both render a named template. `include` returns a string (pipeable to other functions, e.g., `| indent 4`). `template` is an action that writes directly. Always prefer `include` — composable.

**Q8. What are Helm hooks?**
Lifecycle annotations (`helm.sh/hook: pre-install,post-upgrade`) on resources to run them at specific phases: pre/post install, upgrade, delete, rollback. Used for DB migrations, validation tests. Hooks are NOT tracked in release manifests by default.

**Q9. What's a hook-delete-policy?**
Controls hook resource cleanup: `before-hook-creation` (default), `hook-succeeded`, `hook-failed`. Without it, repeated upgrades accumulate Job objects.

**Q10. Difference between application and library charts?**
Application: deployable (default). Library: shared templates, can't be installed alone, included as dependency. Use library for org-wide common templates (labels, security contexts).

---

## Dependencies & Repositories

**Q11. How do chart dependencies work?**
List in `Chart.yaml` under `dependencies:` with name, version, repository. Run `helm dependency update` — pulls into `charts/` and locks in `Chart.lock`. Subchart values namespaced under their name in parent values.

**Q12. How do you override subchart values?**
Top-level key in parent values matching subchart name: `redis: { auth: { password: foo } }`. Or via `--set redis.auth.password=foo`. Use `global:` for values shared across all subcharts.

**Q13. What is condition/tags in dependencies?**
`condition: redis.enabled` — subchart only rendered if value is true. `tags: [database]` — group multiple subcharts to enable/disable together via `tags.database=false`.

**Q14. What's a Helm repository?**
HTTP server hosting `index.yaml` (chart catalog) and chart tarballs. Add via `helm repo add`. OCI registries (Harbor, ECR, Docker Hub) also supported as of Helm 3.8.

**Q15. How do you publish a chart to OCI?**
`helm package mychart`, then `helm push mychart-1.0.0.tgz oci://registry.example.com/charts`. Pull with `helm pull oci://...`. Modern best practice — same registry as images, signed with cosign.

---

## Releases & Lifecycle

**Q16. What does `helm upgrade --install` do?**
Install if release doesn't exist, upgrade if it does. Idempotent — preferred for CI/CD pipelines. Always combine with `--atomic` for auto-rollback on failure.

**Q17. What does `--atomic` do?**
On failure, automatically rolls back to the previous successful release. Also implies `--wait`. Use in CI to avoid leaving the cluster in a partial state.

**Q18. How does Helm track release state?**
Stores release manifests as Secrets (one per revision) in the release namespace under name `sh.helm.release.v1.<name>.v<rev>`. View with `kubectl get secret -l owner=helm`.

**Q19. What is a three-way merge in Helm 3?**
On upgrade, Helm compares old manifest (last release), new manifest (rendered chart), and live state (cluster). Merges to preserve manual edits where possible. Same model as `kubectl apply`.

**Q20. How do you rollback a release?**
`helm rollback <release> <revision>`. Lists with `helm history <release>`. Rollbacks count as new revisions — you can rollback the rollback.

**Q21. What does `helm uninstall --keep-history` do?**
Removes resources but keeps release history, allowing rollback to "resurrect" the release. Without it, uninstall is permanent.

**Q22. Why might `helm upgrade` fail with "no resource match"?**
The chart references a CRD that isn't installed. CRDs in `crds/` directory are install-only (not upgraded). Install CRDs separately or use a chart that handles them as templates.

---

## Operations & Debugging

**Q23. How do you preview what Helm will render?**
`helm template <release> <chart>` — pure local render, no cluster. `helm install --dry-run --debug` — also runs server-side validation. Use template for diffs, dry-run for "will this actually install?".

**Q24. How do you diff before upgrading?**
`helm-diff` plugin: `helm diff upgrade <release> <chart> -f values.yaml`. Shows manifest changes. Essential before any prod upgrade.

**Q25. What are common upgrade pitfalls?**
Immutable fields changed (Job spec, Service ClusterIP) — Helm can't update, you must delete/recreate. PVC size changes (only some StorageClasses allow). Removed templates leave orphaned resources unless --cleanup-on-fail.

**Q26. How do you handle Secrets in values.yaml?**
Don't commit plaintext. Options: helm-secrets (sops + git), External Secrets Operator (fetch from Vault/AWS at runtime), sealed-secrets (encrypt sealed values), or pass via `--set` from CI secret store.

**Q27. What is the `lookup` function and what's its caveat?**
`lookup "v1" "Secret" "ns" "name"` queries the cluster at render time. Returns empty during `helm template` (no cluster). Use sparingly — makes charts non-deterministic.

**Q28. Why is `tpl` useful?**
Renders a template string from values: `tpl .Values.podAnnotations .` — lets users put template expressions in values. Powerful for shared charts that need user-side templating.

---

## Best Practices

**Q29. How do you structure values for environments?**
Base `values.yaml` with safe defaults. `values-dev.yaml`, `values-prod.yaml` with overrides. Compose: `helm upgrade -f values.yaml -f values-prod.yaml`. Avoid embedding env logic in templates — values do that.

**Q30. Should you always pin chart versions?**
Yes. `helm install foo bar/foo --version 1.2.3`. Without pinning, repeated installs may pick a newer chart with breaking changes. Same principle as image tags.

**Q31. Library chart vs umbrella chart?**
Library: shared template helpers, included by other charts. Umbrella: a chart with subchart dependencies, deploys an entire stack. Both have their use; don't confuse them.

**Q32. When would you NOT use Helm?**
Single small app — raw kustomize is simpler. Strict GitOps shops sometimes prefer kustomize for cleaner diffs. Operator-managed apps (Postgres operator) deliver lifecycle management Helm can't match. Helm shines for app distribution and complex multi-resource apps.
