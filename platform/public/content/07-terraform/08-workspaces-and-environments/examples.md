# Examples

## Workspace basics
```bash
terraform init
terraform workspace list           # * default
terraform workspace new dev
terraform workspace new prod
terraform workspace show           # prod
terraform workspace select dev
terraform apply
terraform workspace delete prod    # only if empty (no resources)
```

State files end up at:
- `terraform.tfstate.d/dev/terraform.tfstate`
- `terraform.tfstate.d/prod/terraform.tfstate`

## Per-workspace tfvars
```bash
terraform apply -var-file="envs/${terraform.workspace}.tfvars"
# or in CI:
terraform apply -var-file="envs/$(terraform workspace show).tfvars"
```

## Directory-per-env layout
```bash
infra/
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── backend.tf
    │   ├── main.tf            # module "app" { source = "../../modules/app" ... }
    │   └── terraform.tfvars
    └── prod/
        ├── backend.tf
        ├── main.tf
        └── terraform.tfvars
```

```bash
cd infra/envs/prod
terraform init
terraform plan
terraform apply
```

## Switching providers per env
```hcl
# envs/prod/main.tf
provider "aws" {
  region = "eu-west-1"
  assume_role { role_arn = "arn:aws:iam::PROD_ACCT:role/Terraform" }
}
```
