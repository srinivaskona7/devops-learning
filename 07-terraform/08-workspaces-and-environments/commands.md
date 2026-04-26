# Workspaces & Environments — Commands

> Quick pickup reference. Pair with `README.md` and `examples.md` for theory.

## Setup

```bash
cd 08-workspaces-and-environments
terraform init

# Or for the directory-per-env pattern:
# cd ../infra/envs/dev && terraform init
```

## Init / plan / apply

```bash
# Workspace-based flow
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform plan
terraform apply -auto-approve

# Per-workspace tfvars (handy convention)
terraform apply -var-file="envs/$(terraform workspace show).tfvars"

# Directory-per-env flow (each dir has its own backend + state)
cd envs/prod
terraform init
terraform plan
terraform apply

# Terragrunt flow (when using a terragrunt.hcl per env)
terragrunt init
terragrunt plan
terragrunt apply
terragrunt run-all apply         # multi-stack, dependency-ordered
```

## State operations

```bash
# Each workspace gets its own state file under terraform.tfstate.d/
ls terraform.tfstate.d/
ls terraform.tfstate.d/dev/

# Move a resource between workspaces? Pull, edit, push:
terraform workspace select dev
terraform state pull > dev.tfstate
terraform workspace select staging
terraform state push dev.tfstate    # DANGEROUS — back up first
```

## Inspect / verify

```bash
terraform workspace list           # * marks current
terraform workspace show           # current name only

# Reference the workspace name inside HCL: terraform.workspace
terraform console <<<'terraform.workspace'

# Confirm state path of current workspace
terraform state pull | jq '.serial, .lineage'
```

## Cleanup (destroy)

```bash
# Always destroy resources before deleting the workspace
terraform workspace select dev
terraform destroy -auto-approve

terraform workspace select default
terraform workspace delete dev
terraform workspace delete -force prod      # only if you know what you're doing
```

## One-liners worth memorising

```bash
# Loop apply across every workspace (CI helper)
for ws in dev staging prod; do
  terraform workspace select "$ws" && \
    terraform apply -var-file="envs/${ws}.tfvars" -auto-approve
done

# Show current workspace in your shell prompt (zsh)
# PROMPT='%n@%m %1~ [tf:$(terraform workspace show 2>/dev/null)] %# '

# Guard rail: refuse to apply in prod from a laptop
[[ "$(terraform workspace show)" == "prod" ]] && { echo "use CI"; exit 1; }

# Migrate from workspaces to directory-per-env
terraform workspace select dev
terraform state pull > ../envs/dev/imported.tfstate
# then in envs/dev/: terraform state push imported.tfstate
```
