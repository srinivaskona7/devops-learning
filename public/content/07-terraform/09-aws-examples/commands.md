# AWS Examples — Commands

> Quick pickup reference. Pair with `README.md` for theory.
> EKS costs real money — always destroy after testing.

## Setup

```bash
cd 09-aws-examples

# Auth (pick one)
aws configure                               # writes ~/.aws/credentials
aws sso login --profile my-sso              # SSO + named profile
export AWS_PROFILE=my-sso
export AWS_REGION=eu-west-1

# Verify identity
aws sts get-caller-identity
```

## Init / plan / apply

```bash
terraform init
terraform plan
terraform plan -out=tfplan
terraform apply tfplan

# Apply individual files only (target one resource at a time)
terraform apply -target=aws_s3_bucket.demo
terraform apply -target=aws_vpc.main
terraform apply -target=module.eks

# Variable overrides
terraform apply -var="region=us-east-1"
```

## State operations

```bash
terraform state list
terraform state show aws_s3_bucket.demo
terraform state show aws_vpc.main

# Adopt an existing AWS resource into state
terraform import aws_s3_bucket.adopted my-existing-bucket
terraform import aws_vpc.imported vpc-0123456789abcdef0
```

## Inspect / verify

```bash
# Outputs typically include bucket name, VPC id, EKS endpoint
terraform output
terraform output -raw bucket_name
terraform output -raw cluster_endpoint

# Verify with the AWS CLI
aws s3 ls
aws s3api get-bucket-versioning --bucket "$(terraform output -raw bucket_name)"
aws ec2 describe-vpcs --vpc-ids "$(terraform output -raw vpc_id)"

# EKS — wire up kubectl
aws eks update-kubeconfig \
  --name "$(terraform output -raw cluster_name)" \
  --region "$AWS_REGION"
kubectl get nodes
kubectl get pods -A
```

## Cleanup (destroy)

```bash
# EKS first if it depends on the VPC
terraform destroy -target=module.eks -auto-approve
terraform destroy -auto-approve

# Sanity-check nothing is left billing
aws eks list-clusters
aws ec2 describe-vpcs --filters Name=tag:managed_by,Values=terraform
aws s3 ls | grep demo
```

## One-liners worth memorising

```bash
# Drift check across the whole stack
terraform plan -refresh-only -no-color | tee drift.log

# Plan only the cheap resources (skip EKS while iterating)
terraform plan -target=aws_s3_bucket.demo -target=aws_vpc.main

# Scoped destroy when you only want EKS gone
terraform destroy -target=module.eks -auto-approve

# Switch region without editing code
TF_VAR_region=us-east-1 terraform plan

# Force-replace a tainted resource (e.g. corrupted bucket policy)
terraform apply -replace=aws_s3_bucket.demo
```
