# Testing & Quality Gates — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 12-testing

# Tooling
brew install tflint tfsec terraform-docs
pip install checkov
go install github.com/gruntwork-io/terratest/modules/terraform@latest  # for terratest

# Initialise tflint (downloads ruleset plugins from .tflint.hcl)
tflint --init
```

## Init / plan / apply

```bash
# fmt + validate need only providers — no backend
terraform fmt -recursive -check
terraform init -backend=false
terraform validate

# Built-in tests (Terraform >= 1.6) — uses tests/*.tftest.hcl
terraform init
terraform test
terraform test -filter=tests/main.tftest.hcl
terraform test -verbose
```

## State operations

```bash
# `terraform test` runs in an ephemeral state — no persistent cleanup needed.
# Tests with command = apply auto-destroy when the run block finishes.

# If a test crashed mid-apply, find leftovers:
terraform state list
terraform destroy -auto-approve
```

## Inspect / verify

```bash
# Lint pass
tflint
tflint --recursive
tflint --format=json

# Security scans
tfsec .
tfsec --format=json --out=tfsec-report.json
checkov -d .
checkov -d . --framework terraform --output=cli

# Auto-doc the module
terraform-docs markdown table . > README.generated.md

# Single quality-gate pipeline (mirrors what CI runs)
terraform fmt -check -recursive && \
terraform init -backend=false && \
terraform validate && \
tflint && \
tfsec . && \
terraform test
```

## Cleanup (destroy)

```bash
# In case a test left resources behind
terraform destroy -auto-approve

# Wipe local artefacts
rm -rf .terraform terraform.tfstate*
rm -f tfsec-report.json checkov-report.* tfplan
```

## One-liners worth memorising

```bash
# Run the full local quality gate in one go
terraform fmt -check -recursive && terraform validate && tflint && tfsec . && terraform test

# Just the tests, fail fast
terraform test || { echo "tests failed"; exit 1; }

# Skip a specific tfsec check
tfsec . --exclude=aws-s3-encryption-customer-key

# Generate a checkov SARIF for upload to GitHub code scanning
checkov -d . --output sarif --output-file-path checkov.sarif

# Run a terratest suite (Go)
cd test && go test -v -timeout 30m
```
