# Terraform in CI/CD — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 13-cicd
ls                         # github-actions-terraform.yaml, README.md

# Drop the workflow into a real repo
mkdir -p ../../.github/workflows
cp github-actions-terraform.yaml ../../.github/workflows/terraform.yml

# Configure repo secrets / vars (gh CLI)
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::ACCT:role/github-terraform"
gh variable set AWS_REGION --body "eu-west-1"
```

## Init / plan / apply

```bash
# What CI typically runs (mirror locally before pushing)
terraform fmt -check -recursive
terraform init -input=false -backend-config="bucket=my-tf-state-prod"
terraform validate
terraform plan -input=false -out=tfplan
terraform show -no-color tfplan > tfplan.txt
terraform apply -input=false -auto-approve tfplan

# Trigger workflows from your machine
gh workflow run terraform.yml --ref main
gh workflow run terraform.yml -f environment=staging
```

## State operations

```bash
# Pin TF version in CI
echo "1.9.8" > .terraform-version

# Backend config from CI env vars (no secrets in HCL)
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}"

# If a CI job died mid-apply and left the lock taken
terraform force-unlock <LOCK_ID>
```

## Inspect / verify

```bash
# Watch / inspect runs
gh run list --workflow=terraform.yml
gh run view <RUN_ID> --log
gh run watch
gh run view <RUN_ID> --log-failed

# Pull the saved plan artifact and re-show it
gh run download <RUN_ID> --name tfplan
terraform show -no-color tfplan

# Confirm OIDC role assumption (AWS) inside the runner
aws sts get-caller-identity
```

## Cleanup (destroy)

```bash
# Manual destroy via workflow_dispatch (if your workflow exposes it)
gh workflow run terraform.yml -f action=destroy -f environment=dev

# Local destroy mirroring the CI flow
terraform init -input=false
terraform destroy -input=false -auto-approve

# Remove the workflow file when retiring an env
git rm .github/workflows/terraform.yml && git commit -m "retire tf workflow"
```

## One-liners worth memorising

```bash
# Validate the workflow YAML before pushing
gh workflow view terraform.yml
yamllint .github/workflows/terraform.yml

# Re-run only the failed jobs of a run
gh run rerun <RUN_ID> --failed

# Save & re-apply: guarantees apply == reviewed plan
terraform plan -out=tfplan && terraform apply tfplan

# Scheduled drift check (cron 0 4 * * *) — alert on non-zero exit
terraform plan -detailed-exitcode -refresh-only

# Test OIDC trust policy locally with assume-role-with-web-identity
aws sts assume-role-with-web-identity --role-arn "$AWS_ROLE_ARN" \
  --role-session-name local-test --web-identity-token "$OIDC_TOKEN"
```
