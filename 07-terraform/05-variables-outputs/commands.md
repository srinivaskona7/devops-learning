# Variables & Outputs — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 05-variables-outputs
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to fit your project
terraform fmt
```

## Init / plan / apply

```bash
terraform init

# Defaults only (uses the var defaults baked into variables.tf)
terraform plan

# tfvars file (auto-loaded if named terraform.tfvars or *.auto.tfvars)
terraform plan -var-file=terraform.tfvars

# Inline override on the CLI (highest precedence among flags)
terraform plan -var="env=staging" -var="instance_count=4"

# Environment variable wins over tfvars
TF_VAR_env=staging terraform plan
TF_VAR_db_password='supersecret' terraform apply -auto-approve

# Multiple var files (later files override earlier ones)
terraform apply -var-file=base.tfvars -var-file=prod.auto.tfvars
```

## State operations

```bash
terraform state list

# Outputs are stored in state — inspect them
terraform state pull | jq '.outputs'
```

## Inspect / verify

```bash
# Read all outputs after apply
terraform output
terraform output resource_prefix
terraform output -raw resource_prefix          # unquoted, for scripts
terraform output -json merged_tags | jq .
terraform output -json public_subnets | jq .

# Sensitive output is masked in the table view; force-show:
terraform output db_password_redacted          # <sensitive>
terraform output -raw db_password_redacted     # actual value (be careful)

# Try a variable validation rule live
terraform plan -var="project_name=BadName"     # fails the regex validation
terraform plan -var="instance_count=99"        # fails the 1..10 validation

# Test variable type coercion in console
terraform console
> var.subnet_config["a"].cidr_block
> [for k, v in var.subnet_config : k if v.public]
```

## Cleanup (destroy)

```bash
terraform destroy -auto-approve
rm -f terraform.tfvars            # remove only if it held real secrets
rm -rf .terraform terraform.tfstate*
```

## One-liners worth memorising

```bash
# All-from-env: feed every variable from the shell
export TF_VAR_project_name=demo TF_VAR_env=dev TF_VAR_db_password=$(openssl rand -hex 16)
terraform apply -auto-approve

# Pipe outputs into other tools
export BUCKET=$(terraform output -raw resource_prefix)
aws s3 ls "s3://${BUCKET}-data/"

# Show the resolved value of every variable without applying
terraform console <<<'var'

# Force-rebuild the auto-loaded var file in CI
terraform plan -var-file="envs/${ENV}.tfvars" -out=tfplan
```
