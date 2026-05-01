# 07 · Terraform — commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00." Pane labels match the mental sequence: triage first, diagnose, then act — always reversible until the last step.

---

## Pane 1 — triage (read-only, no state writes)

```bash
terraform version                                   # client + provider versions
terraform providers                                 # tree of providers actually in use
terraform state list                                # addresses Terraform owns in this backend
terraform state show aws_s3_bucket.logs             # every attribute of one resource
terraform output                                    # all outputs
terraform output -json | jq .                       # outputs as JSON for scripts
terraform output -raw db_endpoint                   # unquoted single value
terraform workspace show                            # current workspace (if using them)
```

---

## Pane 2 — diagnose (plan before you touch anything)

```bash
terraform init                                      # download providers + configure backend
terraform init -upgrade                             # bump providers within constraints
terraform init -reconfigure                         # change backend without migrating state
terraform init -migrate-state                       # move state to a new backend
terraform validate                                  # syntax + internal consistency
terraform fmt -check -recursive                     # formatter in CI mode (no rewrites)
terraform plan                                      # diff HCL vs state
terraform plan -refresh-only                        # drift detector — state vs cloud
terraform plan -out=tfplan                          # save the exact diff for apply
terraform show tfplan                               # human-readable plan
terraform show -json tfplan | jq '.resource_changes[] | {addr: .address, actions: .change.actions}'
terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions|contains(["delete","create"])) | "REPLACE: " + .address'
terraform graph | dot -Tsvg > graph.svg             # dependency DAG
terraform console                                   # REPL — evaluate expressions against state
```

---

## Pane 3 — act (mutating, reversible by `plan` + `apply` of the inverse)

```bash
terraform apply tfplan                              # apply exactly the plan you saved + reviewed
terraform apply -auto-approve                       # CI mode — only with a saved plan and a human-approved PR
terraform apply -refresh-only                       # accept drift into state (no cloud change)
terraform apply -target=module.vpc                  # narrow apply (use sparingly; breaks DAG)
terraform apply -replace=aws_db_instance.main       # force a replacement of one resource
terraform destroy                                   # tear down everything in this state
terraform destroy -target=aws_s3_bucket.demo        # destroy just one
terraform taint aws_instance.web                    # mark for replacement on next apply (legacy — prefer -replace)
terraform untaint aws_instance.web                  # undo taint
```

---

## Pane 4 — state surgery (always backup first)

```bash
terraform state pull > /tmp/state.json              # backup before any surgery
terraform state mv aws_s3_bucket.a aws_s3_bucket.b  # rename in state only
terraform state mv module.old.aws_vpc.main module.new.aws_vpc.main
terraform state rm aws_s3_bucket.gone               # forget about a resource (no destroy)
terraform import aws_s3_bucket.adopted my-bucket-id # bring an unmanaged resource into state
terraform refresh                                   # sync state with current cloud reality
terraform force-unlock <LOCK_ID>                    # break a stale DynamoDB lock (know why before you do this)
```

---

## Pane 5 — workspaces (ephemeral only — see concept 6)

```bash
terraform workspace list
terraform workspace new pr-142                      # short-lived PR preview
terraform workspace select pr-142
terraform workspace delete pr-142                   # after PR merge + destroy
```

---

## Pane 6 — quality gates (run before every commit)

```bash
terraform fmt -recursive                            # format everything in the tree
terraform fmt -check -recursive                     # CI check — fails on unformatted files
terraform validate                                  # syntax + types
tflint --init && tflint                             # provider-aware linter
tfsec .                                             # security scanner
checkov -d . --framework terraform --compact        # policy-as-code security
terraform test                                      # built-in test framework (TF >= 1.6)
cd test && go test -v -timeout 30m                  # terratest integration suite
```

---

## Pane 7 — debugging (when plan lies)

```bash
TF_LOG=DEBUG terraform plan                         # verbose — shows provider API calls
TF_LOG=TRACE TF_LOG_PATH=tf.log terraform apply     # full trace to a file
TF_IN_AUTOMATION=1 terraform apply                  # no interactive ANSI noise in CI
terraform state replace-provider registry.terraform.io/-/aws registry.terraform.io/hashicorp/aws
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
rm -rf .terraform .terraform.lock.hcl && terraform init    # nuclear reinit (only after backup)
```

---

## Pane 8 — remote state &amp; locks (S3 + DynamoDB)

```bash
# Inspect backend config
cat backend.tf

# DynamoDB lock table (create once per backend)
aws dynamodb create-table \
  --table-name acme-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# S3 bucket for state (create once per backend)
aws s3api create-bucket --bucket acme-tfstate-prod --region us-east-1
aws s3api put-bucket-versioning --bucket acme-tfstate-prod --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket acme-tfstate-prod \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
aws s3api put-public-access-block --bucket acme-tfstate-prod \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Read current state (remote)
terraform state pull | jq '.resources[].instances[].attributes | keys'
```

---

## Pane 9 — CI/CD (GitHub Actions + OIDC)

```bash
# Assume-role locally with the same OIDC pattern used in CI (for reproducing bugs)
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::111122223333:role/tf-prod-plan \
  --role-session-name debug \
  --web-identity-token "$OIDC_TOKEN" \
  --duration-seconds 3600

# Minimum env vars for a CI runner
export TF_IN_AUTOMATION=1
export TF_INPUT=0
export TF_CLI_ARGS_apply="-input=false -auto-approve"

# Atlantis (server mode) — useful commands on a PR
# atlantis plan -d environments/prod
# atlantis apply -d environments/prod

# Terragrunt (DRY wrapper)
terragrunt init
terragrunt plan
terragrunt run-all plan     # across all environments/*/terragrunt.hcl
```

---

## Pane 10 — modules (consume &amp; publish)

```bash
# Consume a registry module with a pinned version
# module "vpc" { source = "terraform-aws-modules/vpc/aws"; version = "~> 5.13" }
terraform get -update                               # refresh module sources
cat .terraform/modules/modules.json | jq '.Modules[] | {Key, Version}'

# Publish your own module to the registry
# 1) Naming: terraform-<provider>-<name>   e.g. terraform-aws-eks-addons
# 2) Layout: main.tf, variables.tf, outputs.tf, README.md, examples/, tests/
# 3) Tag: git tag v1.0.0 && git push origin v1.0.0
# 4) Registry picks up tags matching vX.Y.Z

# Consume from git with a pinned ref
# module "eks" {
#   source = "git::https://github.com/acme/modules.git//eks?ref=v2.3.1"
# }
```

---

## Pane 11 — secrets hygiene (the panic checklist)

```bash
# 1. Check .gitignore blocks the obvious offenders
grep -E 'tfstate|tfvars|.terraform' .gitignore || echo "ADD THEM NOW"

# 2. Search for secret values accidentally committed to the tree
git log -p -- '*.tfstate' '*.tfstate.backup' | head
grep -rE 'password|secret|token' --include='*.tf' . | grep -v '# '

# 3. Rotate any secret that ever touched state
#    (Secrets Manager: console -> Rotate now)

# 4. Migrate to AWS-managed rotation
#    resource "aws_db_instance" "main" { manage_master_user_password = true }

# 5. Encrypt the state backend at rest
aws s3api put-bucket-encryption --bucket acme-tfstate-prod ...

# 6. Lock bucket ACL to a single IAM role
aws s3api put-bucket-policy --bucket acme-tfstate-prod --policy file://backend-policy.json
```

---

## Pane 12 — HCL patterns you'll paste daily

```hcl
# locals — derived, private, not an input
locals {
  common_tags = merge(var.tags, { Env = var.env, ManagedBy = "terraform" })
  is_prod     = var.env == "prod"
}

# count — positional list; index identity changes if you reorder
resource "aws_instance" "web" {
  count         = var.replicas
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
}

# for_each — keyed map; identity is stable, prefer over count
resource "aws_iam_user" "team" {
  for_each = toset(var.usernames)
  name     = each.key
}

# conditional
instance_type = local.is_prod ? "m5.large" : "t3.small"

# dynamic block — generate nested blocks from a list
dynamic "ingress" {
  for_each = var.ports
  content {
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

# data source — read, don't manage
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# lifecycle — guardrails on resource behaviour
resource "aws_s3_bucket" "logs" {
  bucket = "acme-logs"
  lifecycle {
    prevent_destroy       = true            # block terraform destroy
    create_before_destroy = true            # for resources that must replace without downtime
    ignore_changes        = [tags["LastSeen"]]
  }
}

# variable with validation
variable "env" {
  type        = string
  description = "Environment — dev, staging, or prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging, or prod."
  }
}

# output marked sensitive
output "db_secret_arn" {
  value     = aws_db_instance.main.master_user_secret[0].secret_arn
  sensitive = true
}

# module call with pinned version
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"
  name    = "acme-${var.env}"
}
```

---

## Pane 13 — the 03:00 checklist

When something goes wrong in prod and you have Terraform in your hands, run these in order:

```bash
# 1. Never apply without reviewing a saved plan
terraform plan -out=tfplan
terraform show tfplan | less

# 2. Check for the killers
terraform show -json tfplan \
  | jq -r '.resource_changes[] | select(.change.actions|contains(["delete","create"])) | .address'

# 3. Verify you are in the right backend / account
terraform state pull | jq '.backend'
aws sts get-caller-identity

# 4. Back up state before any write
terraform state pull > /tmp/state-$(date +%s).json

# 5. Lock status — is someone else applying?
aws dynamodb scan --table-name acme-tf-locks --max-items 5

# 6. If all clear, apply the saved plan (not a fresh plan)
terraform apply tfplan

# 7. Post-apply sanity
terraform plan                 # must say "No changes"
terraform output -json | jq .  # all expected outputs present
```

> **Rule of thumb.** A command is safe to run at 03:00 if it is either read-only, or produces an artefact (a plan, a backup) you can review before the mutating step. If it both mutates *and* has no artefact, sleep on it.
