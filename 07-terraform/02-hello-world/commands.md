# Hello, Terraform — Commands

> Quick pickup reference. Pair with `README.md` and `walkthrough.md` for theory.

## Setup

```bash
cd 02-hello-world
ls               # main.tf, README.md, walkthrough.md
terraform fmt    # tidy formatting
```

## Init / plan / apply

```bash
# Download the random + local providers into .terraform/
terraform init

# Show what will be created (expect: 2 to add)
terraform plan

# Save the plan and apply exactly that
terraform plan -out=tfplan
terraform apply tfplan

# Or apply directly (will prompt for 'yes')
terraform apply
terraform apply -auto-approve     # skip the prompt — fine for labs
```

## State operations

```bash
terraform state list                  # random_pet.name, local_file.hello
terraform state show random_pet.name
terraform state show local_file.hello

# Backup before any surgery
cp terraform.tfstate terraform.tfstate.bak
```

## Inspect / verify

```bash
# View outputs after apply
terraform output
terraform output pet_name
terraform output -raw pet_name        # unquoted, scriptable
terraform output -json | jq .

# Confirm the file exists on disk
cat hello.txt
ls -l hello.txt

# Visualize the dependency graph
terraform graph | dot -Tsvg > graph.svg

# Re-run plan — should report no changes (idempotent)
terraform plan
```

## Cleanup (destroy)

```bash
terraform destroy
terraform destroy -auto-approve

# Tidy local cruft (safe — providers will be re-downloaded on next init)
rm -rf .terraform terraform.tfstate*
rm -f hello.txt tfplan
```

## One-liners worth memorising

```bash
# Full lifecycle in one shot
terraform init && terraform apply -auto-approve && cat hello.txt && terraform destroy -auto-approve

# Force-replace the random_pet (rotates the name on next apply)
terraform apply -replace=random_pet.name

# What providers got pinned by init?
cat .terraform.lock.hcl

# Compare your config against current state without writing a plan file
terraform plan -refresh-only
```
