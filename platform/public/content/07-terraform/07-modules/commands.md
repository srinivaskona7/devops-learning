# Modules — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 07-modules
ls                # modules/, README.md
ls modules/       # vpc-stub/

# Scaffold a new local module
mkdir -p modules/my-module
touch modules/my-module/{main.tf,variables.tf,outputs.tf,README.md}
```

## Init / plan / apply

```bash
# init downloads remote modules + providers
terraform init

# Re-fetch modules after editing source/version
terraform init -upgrade
terraform get -update            # modules only, no provider work

# Plan / apply (root config calling child modules)
terraform plan
terraform apply -auto-approve

# Target only one module's resources (emergencies only)
terraform apply -target='module.vpc'
terraform apply -target='module.vpc.random_pet.subnet[0]'
```

## State operations

```bash
# Module-prefixed addresses
terraform state list | grep '^module\.'
terraform state show 'module.vpc.random_pet.subnet[0]'

# Move a resource into / out of a module after refactor
terraform state mv 'random_pet.x' 'module.vpc.random_pet.x'
terraform state mv 'module.old' 'module.new'
```

## Inspect / verify

```bash
# Show every module the root depends on
terraform providers              # also lists module-provider mapping

# What did init download into .terraform/modules/?
cat .terraform/modules/modules.json | jq .
ls .terraform/modules/

# Module outputs (root must re-expose them)
terraform output
terraform output -json | jq .

# Auto-generate module README from variables/outputs
brew install terraform-docs
terraform-docs markdown table modules/vpc-stub > modules/vpc-stub/README.md
terraform-docs markdown table . > README.generated.md
```

## Cleanup (destroy)

```bash
terraform destroy -auto-approve

# Destroy only one module's resources
terraform destroy -target='module.vpc' -auto-approve

# Wipe local module cache (next init re-fetches)
rm -rf .terraform/modules
rm -rf .terraform terraform.tfstate*
```

## One-liners worth memorising

```bash
# Pin a registry module strictly
# module "vpc" { source = "terraform-aws-modules/vpc/aws"  version = "~> 5.13" }

# Use a private git module pinned to a tag
# source = "git::ssh://git@github.com/org/tf-modules.git//vpc?ref=v1.2.0"

# Confirm module versions resolved by init
grep -A1 '"Source"' .terraform/modules/modules.json

# Quick lint pass over every nested module
terraform fmt -recursive -check
find . -type d -name '.terraform' -prune -o -name '*.tf' -print | xargs -n1 terraform fmt -check
```
