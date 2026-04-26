# Terraform Cheatsheet

## Lifecycle
```bash
terraform init                  # download providers, init backend
terraform init -upgrade         # upgrade provider versions
terraform init -migrate-state   # move state between backends
terraform fmt -recursive        # format .tf files
terraform validate              # syntax + internal consistency
terraform plan                  # show diff
terraform plan -out=tfplan      # save plan to file
terraform apply tfplan          # apply saved plan (no re-prompt)
terraform apply -auto-approve   # CI mode
terraform destroy               # tear down everything
terraform destroy -target=aws_s3_bucket.demo  # destroy single resource
```

## State
```bash
terraform state list                          # list resources in state
terraform state show aws_s3_bucket.demo       # inspect one resource
terraform state mv aws_s3_bucket.a aws_s3_bucket.b   # rename in state
terraform state rm aws_s3_bucket.demo         # remove from state (no destroy)
terraform import aws_s3_bucket.demo my-bucket # bring existing resource under TF
terraform refresh                             # sync state with reality
terraform state pull > backup.tfstate         # download remote state
```

## Workspaces
```bash
terraform workspace list
terraform workspace new dev
terraform workspace select prod
terraform workspace show
terraform workspace delete dev
```

## Output / debug
```bash
terraform output                  # show all outputs
terraform output -json            # JSON for scripting
terraform output bucket_name      # one value
terraform graph | dot -Tpng > graph.png   # dependency DAG
TF_LOG=DEBUG terraform apply      # verbose logs
TF_LOG_PATH=tf.log terraform plan # log to file
```

## Modules
```bash
terraform get -update             # refresh modules
terraform init -upgrade           # also upgrades modules
```

## Common HCL snippets
```hcl
# locals
locals {
  common_tags = { Env = var.env, Owner = "platform" }
}

# count
resource "aws_instance" "web" {
  count = 3
  ami   = "ami-123"
}

# for_each (map)
resource "aws_iam_user" "team" {
  for_each = toset(["alice", "bob"])
  name     = each.key
}

# conditional
instance_type = var.env == "prod" ? "m5.large" : "t3.small"

# dynamic block
dynamic "ingress" {
  for_each = var.ports
  content {
    from_port = ingress.value
    to_port   = ingress.value
    protocol  = "tcp"
  }
}

# data source
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

## Quality gates (run before commit)
```bash
terraform fmt -recursive -check
terraform validate
tflint
tfsec .            # or: checkov -d .
terraform test     # built-in tests (TF >= 1.6)
```
