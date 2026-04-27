###############################################################################
# Environment: dev
# Small cluster for development/testing. Single NAT GW to save cost.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    # Fill in after copying backend-s3.tf.example → backend-s3.tf
    # Or use: terraform init -backend-config="bucket=my-tf-state" ...
  }
}

module "eks_cluster" {
  source = "../../"

  aws_region  = var.aws_region
  environment = "dev"
  tags        = var.tags

  # VPC
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = true  # save ~$100/month in dev

  # EKS
  cluster_name              = "eks"
  cluster_version           = "1.30"
  node_group_instance_types = ["t3.medium"]
  node_group_min_size       = 2
  node_group_max_size       = 4
  node_group_desired_size   = 2
  endpoint_public_access    = true   # dev: allow public access (restrict to VPN/office CIDR in prod)
  public_access_cidrs       = var.dev_access_cidrs

  # Karpenter
  karpenter_version        = "0.37.0"
  karpenter_instance_types = ["t3.large", "t3.xlarge", "t3a.large", "m5.large", "m5a.large"]
  nodepool_cpu_limit        = "20"
  nodepool_memory_limit     = "80Gi"
  ami_family                = "AL2023"

  # Addons
  alb_controller_version = "1.7.2"
  cert_manager_version   = "v1.14.4"
  route53_zone_id        = var.route53_zone_id
  external_dns_version   = "1.14.4"
  external_dns_domain    = var.external_dns_domain
  ebs_csi_driver_version = "2.29.0"
  metrics_server_version = "3.12.1"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  default = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

variable "dev_access_cidrs" {
  description = "CIDR list allowed to access the EKS public endpoint in dev"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # REPLACE with office/VPN CIDR
}

variable "route53_zone_id" {
  default = ""
}

variable "external_dns_domain" {
  default = ""
}

variable "tags" {
  default = {
    Team    = "platform"
    CostCenter = "engineering"
  }
}

output "kubeconfig_command" {
  value = module.eks_cluster.kubeconfig_command
}

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}
