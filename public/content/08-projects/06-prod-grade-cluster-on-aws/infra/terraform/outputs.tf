###############################################################################
# Outputs — root module
###############################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC provider (without https://)"
  value       = module.eks.oidc_provider_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (EKS nodes + pods)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets (ALB + NAT GW)"
  value       = module.vpc.public_subnet_ids
}

output "kubeconfig_command" {
  description = "Run this command to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (IRSA)"
  value       = module.addons.alb_controller_role_arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver (IRSA)"
  value       = module.addons.ebs_csi_role_arn
}

output "karpenter_role_arn" {
  description = "IAM role ARN for Karpenter controller (IRSA)"
  value       = module.karpenter.controller_role_arn
}
