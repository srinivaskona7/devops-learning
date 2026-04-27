###############################################################################
# Environment: prod
# Production cluster. Three NAT GWs, larger nodes, tighter security.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    # Configure via environment-specific backend config file
    # terraform init -backend-config=backend.hcl
  }
}

module "eks_cluster" {
  source = "../../"

  aws_region  = var.aws_region
  environment = "prod"
  tags        = var.tags

  # VPC — three independent NAT GWs for AZ resilience
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = false  # HA: one NAT GW per AZ

  # EKS — private endpoint only; access via bastion or VPN
  cluster_name              = "eks"
  cluster_version           = "1.30"
  node_group_instance_types = ["m5.xlarge"]
  node_group_min_size       = 3
  node_group_max_size       = 6
  node_group_desired_size   = 3
  endpoint_public_access    = false   # prod: private endpoint only
  public_access_cidrs       = []

  # Karpenter — wider instance family for cost/availability diversity
  karpenter_version = "0.37.0"
  karpenter_instance_types = [
    "m5.large", "m5.xlarge", "m5.2xlarge",
    "m5a.large", "m5a.xlarge",
    "m6i.large", "m6i.xlarge",
    "m6a.large", "m6a.xlarge",
    "c5.xlarge", "c5.2xlarge",
    "r5.large", "r5.xlarge",
  ]
  nodepool_cpu_limit    = "200"
  nodepool_memory_limit = "800Gi"
  ami_family            = "AL2023"

  # Addons — same versions as dev, pinned for stability
  alb_controller_version = "1.7.2"
  cert_manager_version   = "v1.14.4"
  route53_zone_id        = var.route53_zone_id
  external_dns_version   = "1.14.4"
  external_dns_domain    = var.external_dns_domain
  ebs_csi_driver_version = "2.29.0"
  metrics_server_version = "3.12.1"
}

# PodDisruptionBudgets applied after cluster creation
# These protect critical system pods during node drain events
resource "kubernetes_pod_disruption_budget_v1" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "karpenter"
  }
  spec {
    min_available = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "karpenter"
      }
    }
  }

  depends_on = [module.eks_cluster]
}

resource "kubernetes_pod_disruption_budget_v1" "cert_manager" {
  metadata {
    name      = "cert-manager"
    namespace = "cert-manager"
  }
  spec {
    min_available = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "cert-manager"
      }
    }
  }

  depends_on = [module.eks_cluster]
}

resource "kubernetes_pod_disruption_budget_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
  spec {
    min_available = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "aws-load-balancer-controller"
      }
    }
  }

  depends_on = [module.eks_cluster]
}

variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.1.0.0/16"  # distinct from dev
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  default = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.1.16.0/20", "10.1.32.0/20", "10.1.48.0/20"]
}

variable "route53_zone_id" {
  type = string
}

variable "external_dns_domain" {
  type = string
}

variable "tags" {
  default = {
    Team       = "platform"
    CostCenter = "engineering"
  }
}

output "kubeconfig_command" {
  value = module.eks_cluster.kubeconfig_command
}

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}
