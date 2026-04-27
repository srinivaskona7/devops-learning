variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (required by ALB controller)"
  type        = string
}

variable "alb_controller_version" {
  type    = string
  default = "1.7.2"
}

variable "cert_manager_version" {
  type    = string
  default = "v1.14.4"
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for cert-manager DNS-01 challenges"
  type        = string
  default     = ""
}

variable "external_dns_version" {
  type    = string
  default = "1.14.4"
}

variable "external_dns_domain" {
  description = "Domain filter for external-dns (e.g. example.com)"
  type        = string
  default     = ""
}

variable "ebs_csi_driver_version" {
  type    = string
  default = "2.29.0"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.1"
}

variable "tags" {
  description = "Tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}
