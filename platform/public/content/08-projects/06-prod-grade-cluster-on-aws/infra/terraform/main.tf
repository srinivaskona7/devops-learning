###############################################################################
# Root module — wires VPC, EKS, Karpenter, and Addons
###############################################################################

locals {
  cluster_name = "${var.environment}-${var.cluster_name}"
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "prod-eks-stamp"
  })
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name               = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway  # true in dev, false in prod
  tags                 = local.common_tags
}

# ── EKS Cluster ──────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Managed node group — system/addon workloads only
  node_group_instance_types = var.node_group_instance_types
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_desired_size   = var.node_group_desired_size

  # Access
  endpoint_private_access = true
  endpoint_public_access  = var.endpoint_public_access   # false in prod
  public_access_cidrs     = var.public_access_cidrs

  tags = local.common_tags
}

# ── Karpenter ─────────────────────────────────────────────────────────────────
module "karpenter" {
  source = "./modules/karpenter"

  cluster_name       = module.eks.cluster_name
  cluster_endpoint   = module.eks.cluster_endpoint
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  node_iam_role_name = module.eks.node_iam_role_name

  karpenter_version      = var.karpenter_version
  nodepool_cpu_limit     = var.nodepool_cpu_limit
  nodepool_memory_limit  = var.nodepool_memory_limit
  instance_types         = var.karpenter_instance_types
  availability_zones     = var.availability_zones
  ami_family             = var.ami_family
  private_subnet_ids     = module.vpc.private_subnet_ids

  tags = local.common_tags

  depends_on = [module.eks]
}

# ── Cluster Addons (via Helm) ─────────────────────────────────────────────────
module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca        = module.eks.cluster_ca
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id

  # ALB controller
  alb_controller_version = var.alb_controller_version

  # cert-manager
  cert_manager_version  = var.cert_manager_version
  route53_zone_id       = var.route53_zone_id

  # external-dns
  external_dns_version  = var.external_dns_version
  external_dns_domain   = var.external_dns_domain

  # EBS CSI
  ebs_csi_driver_version = var.ebs_csi_driver_version

  # metrics-server
  metrics_server_version = var.metrics_server_version

  tags = local.common_tags

  depends_on = [module.eks, module.karpenter]
}
