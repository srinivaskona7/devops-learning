# Production Best Practices — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 14-best-practices

# Tooling every prod TF repo should have installed
brew install terraform tflint tfsec terraform-docs pre-commit
pip install checkov

# Drop in the recommended .gitignore (see README.md for the template)
cp /path/to/template.gitignore .gitignore

# Pin TF version in the repo
echo "1.9.8" > .terraform-version
```

## Init / plan / apply

```bash
# The "always do this" sequence
terraform fmt -recursive -check
terraform init -input=false
terraform validate
terraform plan -out=tfplan        # save the plan
terraform show -no-color tfplan   # review
terraform apply tfplan            # apply exactly what was reviewed

# Never in prod from a human terminal:
#   terraform apply -auto-approve
#   terraform apply -target=...

# Refresh-only (sync state to reality, no infra changes)
terraform apply -refresh-only
```

## State operations

```bash
# Always back up before surgery
terraform state pull > "backup-$(date +%Y%m%d-%H%M%S).tfstate"

# Common safe operations
terraform state list
terraform state show <addr>
terraform state mv <src> <dst>          # refactor without destroy
terraform import <addr> <cloud_id>      # adopt existing resource

# Dangerous — last resort only
terraform state rm <addr>               # forget (won't delete in cloud)
terraform state push edited.tfstate     # overwrite remote state
terraform force-unlock <LOCK_ID>        # only if you're SURE no apply is running
```

## Inspect / verify

```bash
# Full quality gate (run in CI on every PR)
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint --recursive
tfsec .
checkov -d .
terraform-docs markdown table . > README.md
terraform plan -out=tfplan

# Drift detection (schedule nightly)
terraform plan -detailed-exitcode -refresh-only
# exit codes: 0=no diff, 1=error, 2=diff

# Lifecycle rules in action — confirm prevent_destroy is honoured
terraform destroy           # should fail if prevent_destroy = true
```

## Cleanup (destroy)

```bash
# Production destroy checklist
terraform plan -destroy -out=destroy.tfplan
terraform show -no-color destroy.tfplan | less   # review carefully
terraform apply destroy.tfplan                   # only after sign-off

# Tear down a single stack (envs/dev/) without touching others
cd envs/dev && terraform destroy

# Remove TF metadata locally (state stays in remote backend)
rm -rf .terraform tfplan destroy.tfplan
```

## One-liners worth memorising

```bash
# Recursive fmt check for every module in the repo
terraform fmt -recursive -check -diff

# Generate per-module READMEs with terraform-docs
find . -type f -name 'main.tf' -not -path '*/.terraform/*' \
  -exec dirname {} \; | xargs -I{} terraform-docs markdown table {} -o {}/README.md

# Pre-commit: install repo-side hooks once
pre-commit install
pre-commit run --all-files

# Quickly find which resources have prevent_destroy
grep -rn 'prevent_destroy' --include='*.tf' .

# Show current TF + provider versions baked into the lockfile
terraform version
cat .terraform.lock.hcl | grep -E 'provider|version'

# Spot resources missing default_tags / labels
terraform state pull | jq '.resources[] | select(.values.tags == null) | .address'
```
