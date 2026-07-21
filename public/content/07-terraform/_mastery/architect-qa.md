# Architect Q&A — Terraform / OpenTofu

> 40+ deep questions you will face in design reviews, interviews, and prod
> incidents. Each answer is opinionated and includes a default recommendation.

---

## Section 1: State Management

### Q1. What is the right blast-radius for a single state file?
One state per (environment x region x layer). E.g. `prod-eu-network`,
`prod-eu-platform`, `prod-eu-apps`. Never one giant state. Plans should
finish in under two minutes; if longer, split.

### Q2. Local state vs remote state — when is local acceptable?
Only for throwaway labs and `terraform-docs` rendering. Anything a teammate
might touch goes remote. Default: S3 + DynamoDB lock, or GCS + native lock,
or Terraform Cloud.

### Q3. How do you isolate state across environments?
Three viable patterns:
1. Directory-per-env (recommended default)
2. Workspaces (cheap but dangerous — same code path)
3. Terragrunt-style DRY with separate state per leaf

Pick one and stick with it. Mixing is the worst option.

### Q4. State-file encryption: what do you turn on?
Backend-side encryption (SSE-KMS on S3 with a customer-managed key),
TLS in transit, and never commit the file. Rotate the KMS key annually.
Disable bucket public access via Block Public Access at account level.

### Q5. How do you recover from a corrupted state file?
1. Stop all CI immediately
2. Pull the previous version from backend versioning (S3 versioning is
   non-negotiable)
3. Run `terraform plan` against the previous version
4. If diff is acceptable, push it back as the current version
5. Post-mortem: who/what wrote concurrently? Was the lock bypassed?

### Q6. How do you handle state for resources that must outlive Terraform?
Use `lifecycle { prevent_destroy = true }` and split into a separate state
owned by a different team or pipeline. Crown jewels (KMS keys, root DNS,
billing accounts) live in their own state with manual approval only.

### Q7. When do you reach for `terraform_remote_state` data source?
Sparingly. It creates a hard coupling between states. Prefer SSM Parameter
Store, GCS objects, or a thin "platform-outputs" service. If you must use
it, only read — never write across boundaries.

---

## Section 2: Modules — Monorepo vs Polyrepo

### Q8. Monorepo or polyrepo for Terraform modules?
Monorepo for internal modules used across many teams (single PR can update
all consumers). Polyrepo when modules are versioned and consumed via a
registry (Terraform Cloud Private Registry, Git tags). Hybrid: monorepo for
authoring, registry for consumption.

### Q9. What goes in a module vs a root config?
Module: pure resource composition with inputs/outputs and zero opinions
about backend or providers. Root: backend config, provider config,
environment-specific values, and module instantiation.

### Q10. How do you version shared modules safely?
Tag with SemVer. Major bumps for any input/output rename or removal. Pin
consumers to `~> 2.0`. Maintain a CHANGELOG. Run consumers' plans against
RC tags before promoting to stable.

### Q11. How do you handle a breaking change in a shared module?
1. Cut a new major version
2. Keep the previous major receiving security patches for 90 days
3. Provide a migration script or doc with `terraform state mv` examples
4. Give consumers a deprecation window with deadline
5. Fail CI with a warning, not an error, during the window

### Q12. How small should a module be?
Small enough to test in isolation (under 200 lines of HCL), large enough to
encapsulate a meaningful unit (e.g. "VPC with public/private subnets and
NAT" is one module, not three).

### Q13. When do you use `for_each` vs `count` in modules?
`for_each` always for named resources. `count` only for boolean
"create-or-not" toggles. `count` reorders on removal and causes
unnecessary destroy/create.

---

## Section 3: Workspaces vs Dir-per-env vs Terragrunt

### Q14. Default recommendation for env separation?
Directory-per-environment with a thin shared module layer. Most explicit,
easiest to grep, hardest to misfire.

### Q15. When are workspaces actually a good fit?
Ephemeral PR environments where the code path is identical and the only
variation is a workspace name. Never for prod vs staging.

### Q16. Why do experienced teams pick Terragrunt?
DRY backend config, dependency ordering between states, and `run-all`
across stacks. Cost: another tool, another DSL on top of HCL, and the
team must understand both layers.

### Q17. What's the failure mode of workspaces in prod?
A typo (`terraform workspace select prod` vs `staging`) and you've just
applied staging changes to prod state. There's no syntactic guard.

### Q18. How do Terragrunt dependencies work?
`dependency "vpc" { config_path = "../vpc" }` reads outputs of another
state. Terragrunt orders the apply graph automatically. Useful for
multi-state composition.

---

## Section 4: Drift Detection

### Q19. How do you build a drift detection program?
1. Schedule `terraform plan -detailed-exitcode` per state, hourly or daily
2. Exit code 2 = drift; emit metric to Prometheus/Datadog
3. Alert with the diff attached to a Slack thread
4. Triage SLO: investigate within 24h, resolve within a week
5. Track drift-MTTR as a platform health metric

### Q20. What causes drift you can't fix in code?
Manual console clicks (block them with SCPs/IAM), out-of-band autoscaling
(use `lifecycle { ignore_changes = [...] }`), and provider bugs that
re-surface attributes. Tag and document all three.

### Q21. Auto-heal drift or alert-only?
Alert-only by default. Auto-heal only on explicitly tagged "self-healing"
states (e.g. compliance baselines). Auto-heal on a stateful resource is
how you delete prod data.

### Q22. How do you suppress benign drift?
`lifecycle { ignore_changes = [tags["LastModified"], desired_capacity] }`.
Document each ignore with a comment explaining why. Audit ignores
quarterly — they're tech debt.

---

## Section 5: Secrets

### Q23. Where do secrets live?
Never in `.tf` or `.tfvars`. Use a secrets manager (AWS Secrets Manager,
GCP Secret Manager, HashiCorp Vault). Reference via data source at apply
time. Rotate independent of Terraform.

### Q24. What about secrets in state?
Terraform stores resolved values in state, including secrets. Treat the
state backend as Tier-0 sensitive. Encrypt with KMS. Restrict read access
to the CI service account and break-glass humans only.

### Q25. How do you handle bootstrap secrets (the chicken-and-egg)?
Out-of-band: a human creates the initial root secret in the secrets
manager via console or CLI. Terraform reads it. Document this as a manual
step in the bootstrap runbook.

### Q26. Provider credentials in CI — what's the pattern?
OIDC federation. No long-lived keys. AWS: GitHub OIDC -> IAM role.
GCP: Workload Identity Federation. Azure: Federated Credentials. Each
pipeline gets a least-privilege role.

### Q27. How do you rotate the KMS key that encrypts state?
1. Create new key
2. Re-encrypt the state bucket with the new key (S3 supports this via
   bucket-level setting)
3. Wait for one full apply cycle
4. Schedule old key for deletion (30 days)

---

## Section 6: CI/CD with OIDC

### Q28. Why OIDC over static keys?
No secret to leak, no rotation, scoped to the workflow/repo/branch.
Ephemeral STS credentials. Auditable in CloudTrail with full request
context.

### Q29. What does the OIDC trust policy look like (AWS)?
Trust the GitHub OIDC provider; condition on `repo:org/repo:ref:refs/heads/main`
for prod, looser for plan-only roles. Two roles per env: `tf-plan`
(read-only-ish) and `tf-apply` (write).

### Q30. What does a safe CI pipeline look like?
1. PR opened: `terraform plan` runs with read-only role, posts diff
2. Reviewer approves PR
3. Merge to main: `terraform apply` runs with write role
4. Prod: extra manual approval gate (environment protection rules)
5. Notify Slack on success/failure with state name and diff link

### Q31. How do you prevent drift between PR plan and apply plan?
Save the plan binary as an artifact. Apply must consume that exact plan.
Re-running plan at apply time defeats the review.

### Q32. How do you handle plan-on-fork PRs without leaking creds?
Use `pull_request_target` is dangerous. Default: don't run plan on forks.
Trusted contributors only. Or run plan in a sandbox account with no
real data.

---

## Section 7: Blast Radius

### Q33. What's the practical limit for resources in one state?
Soft cap: 500 resources. Hard cap: 1500. Beyond that, plans take minutes,
locks block teams, and a typo can destroy hours of work.

### Q34. How do you reduce blast radius without exploding state count?
Layer by lifecycle: network (rarely changes), platform (monthly), apps
(daily). Each layer is a state. Apps depend on platform outputs, not
resources.

### Q35. What's the right approval matrix?
Plan-only: any developer. Apply non-prod: developer with review. Apply
prod: developer + on-call approval. Apply Tier-0 (KMS, DNS root, billing):
two humans, one of whom is platform team.

### Q36. How do you make `terraform destroy` safer?
1. `prevent_destroy` on stateful resources
2. Require a special CI workflow with manual confirmation
3. Refuse destroy on production states except via break-glass
4. Always run `plan -destroy` first

---

## Section 8: OpenTofu Migration

### Q37. Why would you migrate from Terraform to OpenTofu?
License clarity (MPL 2.0 vs BSL), community-driven roadmap, drop-in CLI
compatibility for current versions, and avoidance of HashiCorp commercial
lock-in.

### Q38. What's the migration path?
1. Pin Terraform to the last MPL version (1.5.x)
2. Test OpenTofu against that codebase in a sandbox state
3. Replace the binary in CI; state format is compatible up to OpenTofu 1.6
4. Audit provider compatibility (most are unchanged)
5. Cut over per-state, not all at once

### Q39. What breaks?
Terraform Cloud-specific features (Sentinel, run tasks). Replace with
OpenTofu-compatible alternatives or self-hosted Atlantis/Spacelift/env0.

### Q40. How do you support both during transition?
Use `tenv` or `tfenv`-style version manager. CI matrix runs both. Modules
must avoid version-specific syntax until cutover complete.

---

## Section 9: Operational Wisdom

### Q41. How do you handle a stuck state lock?
Identify the holder (`terraform force-unlock` shows the ID). Confirm no
apply is actually running (check CI). Then force-unlock. Never force-unlock
mid-apply — you'll corrupt the state.

### Q42. Refactor: how to rename a resource without destroy/create?
`terraform state mv aws_instance.old aws_instance.new`. Always `plan`
after to confirm zero changes. Commit the code change and the state move
together.

### Q43. How do you adopt existing infra into Terraform?
`terraform import` per resource, then `terraform plan` until clean. For
large estates, use `terraformer` or provider-specific exporters to bulk-
generate HCL, then prune and refactor.

### Q44. How do you test modules?
Three layers: `terraform validate` (syntax), `tflint` + `tfsec` (lint and
security), and `terratest` or `terraform test` (apply in a sandbox account,
assert outputs, destroy). Run all three in PR CI.

### Q45. How do you keep providers up to date?
Renovate or Dependabot for `versions.tf`. Dedicated weekly PR. Always
read the provider changelog before merging — minor versions can introduce
new required attributes.

---

## Closing Principles

- **Boring is good.** Terraform is plumbing. Surprises are bugs.
- **Plans are the contract.** If you skip the plan review, you skipped
  the design review.
- **State is a database.** Treat it like one: backups, locks, encryption,
  audit.
- **Modules are products.** Versioned, documented, supported.
- **Humans approve prod.** Always. No exceptions for "small changes."
