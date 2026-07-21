# State — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
cd 06-state
ls                 # backend-s3.tf, backend-gcs.tf, README.md

# Bootstrap S3 + DynamoDB (one-time, out-of-band)
aws s3 mb s3://my-tf-state-prod --region eu-west-1
aws s3api put-bucket-versioning --bucket my-tf-state-prod \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region eu-west-1

# GCS backend bootstrap
gcloud storage buckets create gs://my-tf-state-prod --location=eu
gcloud storage buckets update gs://my-tf-state-prod --versioning
```

## Init / plan / apply

```bash
# First init against a remote backend
terraform init

# Migrate from local state to a newly-configured remote backend
terraform init -migrate-state

# Re-configure backend (e.g. changed bucket / region) without migrating
terraform init -reconfigure

# Pass backend settings via CLI instead of HCL (CI-friendly)
terraform init \
  -backend-config="bucket=my-tf-state-prod" \
  -backend-config="key=stacks/network/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=tf-locks"
```

## State operations

```bash
terraform state list
terraform state show aws_s3_bucket.demo

# Refactoring — rename without destroy/recreate
terraform state mv aws_s3_bucket.old aws_s3_bucket.new
terraform state mv 'module.app.aws_iam_role.x' 'module.platform.aws_iam_role.x'

# Forget a resource (does NOT delete in cloud)
terraform state rm aws_s3_bucket.legacy

# Adopt an existing cloud resource
terraform import aws_s3_bucket.adopted my-existing-bucket-name

# Sync state with reality (no apply)
terraform refresh
terraform apply -refresh-only

# Pull / push raw state
terraform state pull > backup.tfstate
terraform state push edited.tfstate            # DANGEROUS

# Force-release a stuck lock (only after confirming nobody is applying)
terraform force-unlock <LOCK_ID>
```

## Inspect / verify

```bash
# Where is the backend configured?
cat .terraform/terraform.tfstate | jq '.backend'

# What's in the remote state right now?
terraform state pull | jq '.resources | length'
terraform state pull | jq '.resources[].type' | sort -u

# Confirm versioning is on (S3)
aws s3api get-bucket-versioning --bucket my-tf-state-prod

# Inspect lock table entries (S3 backend)
aws dynamodb scan --table-name tf-locks --region eu-west-1
```

## Cleanup (destroy)

```bash
# Tear down infra first
terraform destroy -auto-approve

# Then (optionally) the backend itself
aws s3 rm s3://my-tf-state-prod --recursive
aws s3 rb s3://my-tf-state-prod
aws dynamodb delete-table --table-name tf-locks --region eu-west-1

gcloud storage rm -r gs://my-tf-state-prod
```

## One-liners worth memorising

```bash
# Always back up before surgery
terraform state pull > "backup-$(date +%s).tfstate"

# Spot drift quickly
terraform plan -refresh-only -no-color | grep -E 'will be|forces replacement'

# Move a whole module under a new key
terraform state mv 'module.vpc' 'module.network.module.vpc'

# Re-init pointing at a different workspace's state path
terraform init -backend-config="key=stacks/network/dev/terraform.tfstate" -reconfigure
```
