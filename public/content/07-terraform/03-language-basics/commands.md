# HCL Language Basics — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 03-language-basics
ls                # examples.tf, README.md
terraform fmt     # auto-format the file
```

## Init / plan / apply

```bash
terraform init
terraform plan                       # review count / for_each / dynamic blocks
terraform apply -auto-approve

# Override a variable on the fly
terraform apply -var="env=prod" -auto-approve
terraform apply -var='team_members=["alice","dave"]' -auto-approve

# Save then apply
terraform plan -out=tfplan && terraform apply tfplan
```

## State operations

```bash
terraform state list

# Indexed (count) addresses
terraform state show 'random_pet.indexed[0]'
terraform state show 'random_pet.indexed[1]'

# Keyed (for_each) addresses
terraform state show 'random_pet.per_member["alice"]'
terraform state show 'local_file.greeting["bob"]'
```

## Inspect / verify

```bash
# View all generated files
ls -1 *.txt
cat alice.txt

# Outputs showcase expressions
terraform output
terraform output -json indexed_pets | jq .
terraform output -json member_pets | jq .
terraform output -json tags | jq .
terraform output -json ports_doubled | jq .

# Try expressions live in the console
terraform console
> upper("hello")
> [for x in range(5) : x * 2]
> { for n in ["a","b"] : n => upper(n) }
> contains(["dev","prod"], "dev")
> ^D    # to exit
```

## Cleanup (destroy)

```bash
terraform destroy -auto-approve
rm -f *.txt tfplan
rm -rf .terraform terraform.tfstate*
```

## One-liners worth memorising

```bash
# Recursively format every .tf file in the tree
terraform fmt -recursive
terraform fmt -check -recursive          # CI-friendly: exits non-zero on diff

# Validate without contacting any backend
terraform init -backend=false && terraform validate

# Render the full DAG as SVG
terraform graph | dot -Tsvg > graph.svg

# Re-create a single keyed resource without touching siblings
terraform apply -replace='random_pet.per_member["alice"]'

# Probe a single expression non-interactively
echo 'upper("hello")' | terraform console
```
