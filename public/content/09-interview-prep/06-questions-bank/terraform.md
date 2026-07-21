# Terraform Q&A Bank

These questions are the ones I've actually been asked / would ask. Terraform interviews focus on state management, module design, and how you handle drift and secrets at scale — not just `terraform apply`.

## How to use

Say each answer out loud, 60-second ceiling. Be ready to whiteboard a state-locking flow or module composition.

---

## Core Concepts

**Q1. What does Terraform actually do?**
Reads HCL config → builds dependency graph of resources → compares desired state to current state (refresh) → computes a plan (create/update/destroy) → executes via providers (REST clients to clouds). State file tracks resource → real-world ID mapping.

**Q2. Why is state important?**
Terraform doesn't introspect your cloud on every run — too slow and unreliable. State maps HCL resource addresses to real IDs (`i-abc123`). Without state, Terraform can't tell create from update from destroy.

**Q3. What's in a state file?**
JSON: resource addresses, attributes (including sensitive!), dependencies, lineage, terraform version, provider versions, outputs. Treat as sensitive — secrets often end up there.

**Q4. Local vs remote state?**
Local: `terraform.tfstate` on disk — only for solo experimentation. Remote: S3/GCS/Azure Blob/Terraform Cloud — required for teams (concurrency, locking, sharing).

**Q5. State locking — why and how?**
Prevents concurrent applies that would corrupt state. S3 backend uses DynamoDB table for locks; gs uses GCS object lock. Terraform Cloud handles natively. Without locking, two engineers applying simultaneously can leave resources orphaned.

**Q6. What is `terraform refresh` doing today?**
Updates state with real-world attributes (not desired state). In modern Terraform, refresh runs implicitly during plan (`-refresh-only` to skip apply). Detects drift between state and reality.

**Q7. Difference between plan and apply?**
plan: dry run — shows proposed changes, exits. apply: executes changes (with optional `-auto-approve`). CI pattern: plan on PR, apply on merge.

**Q8. `terraform import` — when?**
Bring a manually-created resource under Terraform management. Adds to state, doesn't generate config (you write HCL to match). 1.5+ has `import` block for declarative import via plan.

---

## Modules

**Q9. What is a module?**
A reusable bundle of HCL — directory with .tf files. Inputs (variables), outputs, resources. Root module is your config; child modules are called via `module "x" { source = "..." }`.

**Q10. When do you create a module vs inlining?**
Module when: reused across stacks/envs, encapsulates a meaningful unit (vpc, eks-cluster, app-service), or hides complexity. Don't module-ify single-resource wrappers — that's noise.

**Q11. Best practices for module design?**
Small, composable, single-purpose. Required inputs minimal, sensible defaults. Outputs expose IDs others need. Versioned (git tag or registry). README with example. Avoid hardcoded providers — let caller pass them.

**Q12. Where do you source modules?**
Git (with ref pinning: `?ref=v1.2.3`), Terraform Registry (public), private registry (Terraform Cloud, Spacelift), local path (mono-repo). Always pin versions.

**Q13. How do you version modules?**
SemVer tags in git. Major bump for breaking changes (renamed inputs, removed outputs). Use `version = "~> 1.2"` constraint syntax in registry sources.

**Q14. What's a `count` vs `for_each`?**
count: numeric, indexes by integer (resource.foo[0]). for_each: map/set, indexes by key (resource.foo["us-east-1"]). Prefer for_each — adding/removing in middle of count list re-indexes everything (destroy + create).

---

## Providers & State

**Q15. How do providers work?**
Plugins (Go binaries) that translate HCL into API calls. Downloaded into `.terraform/providers/`. Pin versions in `required_providers`. Each provider configured with credentials/region.

**Q16. How do you handle multiple AWS accounts?**
Provider aliases: `provider "aws" { alias = "prod" region = "us-east-1" }`, then `provider = aws.prod` on resources. Use AssumeRole in provider config for cross-account.

**Q17. Workspace vs separate state files?**
Workspaces: multiple states in one backend, same config (good for env-as-data). Separate state per env (different backend keys): cleaner separation, different backends/regions per env. Most teams prefer separate states.

**Q18. How do you split a giant state file?**
`terraform state mv` to move resources between state files. Or `import` into new state and `state rm` from old. Use state file boundaries to limit blast radius — one state per "deployment unit" (e.g., per VPC, per cluster).

**Q19. What is state drift?**
Difference between Terraform state and real-world infrastructure (manual changes via console). Detect with `terraform plan -refresh-only`. Reconcile by either: importing the change into config or reverting.

**Q20. Strategies to prevent drift?**
SCPs/IAM policies blocking console writes. CI-only apply (humans can't run apply locally). Drift detection runs (driftctl, Spacelift, Terraform Cloud). Education + culture.

---

## Secrets & Auth

**Q21. How do you handle secrets in Terraform?**
Don't put in HCL. Pull from secret stores: `data "aws_secretsmanager_secret_version"`, `data "vault_generic_secret"`. Mark variables `sensitive = true` (redacts from plan output but still in state). Encrypt state at rest.

**Q22. What is OIDC for Terraform CI?**
GitHub Actions / GitLab CI uses OIDC to AssumeRole in AWS without long-lived keys. Terraform Cloud has dynamic provider credentials. Standard for modern pipelines — no static creds in CI.

**Q23. Why is `sensitive = true` not enough?**
It only redacts CLI output. The value is still plaintext in state. Encrypt the state backend (S3 SSE, KMS), restrict who can read state, and prefer fetching secrets at runtime over storing in state.

---

## Operations

**Q24. How do you do zero-downtime resource replacement?**
`create_before_destroy` lifecycle: new resource created first, then DNS/LB cuts over, then old destroyed. Required when destroy-then-create would cause outage (e.g., immutable resources like Launch Templates).

**Q25. What does `prevent_destroy` do?**
Lifecycle flag — `terraform destroy` or replace operations on the resource fail. Safety net for stateful resources (RDS, S3 buckets). Doesn't prevent accidental config-driven destroys; pair with state-level guards.

**Q26. How do you handle a Terraform crash mid-apply?**
State may have partial updates. Re-run `terraform apply` — it'll pick up where it left off. If state is corrupt, restore from backend versioning (S3 versioning is non-negotiable). Never edit state file by hand without backup.

**Q27. terraform_remote_state vs data sources?**
remote_state: read another state's outputs (tight coupling between configs). Data sources: query the cloud directly (loose coupling). Prefer data sources — remote_state creates blast-radius dependencies.

**Q28. What is Terragrunt and when would you use it?**
Wrapper for DRY Terraform: keeps backend config, common variables, and module versions in one place across many envs. Use when you have many similar stacks (per-env, per-region) and don't want to copy-paste backend blocks.

---

## Plan & Apply

**Q29. How do you preview only one resource's change?**
`terraform plan -target=aws_instance.foo`. Use sparingly — bypasses dependency graph and can leave inconsistent state. Last resort for unstuck applies.

**Q30. CI pattern for safe applies?**
PR: `terraform fmt -check`, `terraform validate`, `tflint`, `tfsec`/`checkov`, `terraform plan` (post as PR comment). Merge to main: `terraform apply -auto-approve` with required reviewers. Lock environment during apply.

**Q31. How do you detect security misconfigs in HCL?**
Static analysis: tfsec, checkov, terrascan, tflint with security rules. Catches "S3 bucket public", "IAM wildcards", "no encryption". Run in CI on every PR.

**Q32. What is `terraform taint` (now `-replace`)?**
Mark a resource for destruction + recreation on next apply. Modern syntax: `terraform apply -replace="aws_instance.foo"`. Use when a resource is in a bad state but config hasn't changed.
