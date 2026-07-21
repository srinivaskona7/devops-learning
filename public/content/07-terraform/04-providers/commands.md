# Providers — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 04-providers
# This chapter is reference-only (no .tf file). Use a sibling chapter to try
# the commands, e.g.:
cd ../02-hello-world
```

## Init / plan / apply

```bash
# Init pulls every provider listed in required_providers
terraform init

# Force-upgrade providers within the configured constraint
terraform init -upgrade

# Re-init after editing required_providers (won't migrate state, just plugins)
terraform init -reconfigure

# Plan / apply — providers are loaded automatically
terraform plan
terraform apply
```

## State operations

```bash
# State holds which provider produced each resource — visible via:
terraform state show <addr> | grep '^# .* provider'

# Switch a resource to a different provider alias (after refactor)
terraform state replace-provider hashicorp/aws registry.opentofu.org/hashicorp/aws
```

## Inspect / verify

```bash
# Show all providers required + currently selected versions
terraform providers
terraform providers lock         # regenerate lockfile for all platforms
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_arm64 \
  -platform=darwin_amd64        # multi-OS teams need this
terraform providers schema -json | jq '.provider_schemas | keys'

# Inspect the lockfile — the source of provider truth in CI
cat .terraform.lock.hcl

# Where did init drop the plugin binaries?
ls -R .terraform/providers/
```

## Cleanup (destroy)

```bash
# Wipe just the cached provider plugins (next init re-downloads)
rm -rf .terraform/providers

# Wipe everything Terraform-cached locally
rm -rf .terraform .terraform.lock.hcl
```

## One-liners worth memorising

```bash
# Bump every provider to the highest version allowed by constraints
terraform init -upgrade

# Show only the version numbers actually pinned
terraform version

# Mirror providers locally for an air-gapped run
terraform providers mirror ./offline-mirror
# then on the airgapped box:
#   terraform { provider_installation { filesystem_mirror { path = "./offline-mirror" } } }

# Quick check: does a constraint resolve?
terraform init -upgrade 2>&1 | grep -E "Installed|Using"

# List every provider used in a module tree
grep -rh 'source\s*=' --include='*.tf' .
```
