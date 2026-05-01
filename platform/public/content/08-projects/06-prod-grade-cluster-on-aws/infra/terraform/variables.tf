###############################################################################
# Input variables — root module
###############################################################################

# ── General ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "tags" {
  description = "Additional tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ── VPC ──────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs — must match the number of subnet CIDR lists"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT GW (cost-saving in dev). Set false for HA in prod."
  type        = bool
  default     = false
}

# ── EKS ──────────────────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "EKS cluster base name. Full name: {environment}-{cluster_name}"
  type        = string
  default     = "eks"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the system managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in managed node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in managed node group"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in managed node group"
  type        = number
  default     = 2
}

variable "endpoint_public_access" {
  description = "Enable public EKS API endpoint. Set false in prod (requires VPN/bastion)."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access the public EKS endpoint. Ignored if endpoint_public_access=false."
  type        = list(string)
  default     = ["0.0.0.0/0"]  # restrict to office/VPN CIDR in practice
}

# ── Karpenter ─────────────────────────────────────────────────────────────────
variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "0.37.0"
}

variable "karpenter_instance_types" {
  description = "Allowed EC2 instance types for Karpenter NodePool"
  type        = list(string)
  default     = [
    "m5.large", "m5.xlarge", "m5.2xlarge",
    "m5a.large", "m5a.xlarge",
    "m6i.large", "m6i.xlarge",
    "m6a.large", "m6a.xlarge",
  ]
}

variable "nodepool_cpu_limit" {
  description = "Maximum total CPU Karpenter can provision across all nodes"
  type        = string
  default     = "100"
}

variable "nodepool_memory_limit" {
  description = "Maximum total memory Karpenter can provision"
  type        = string
  default     = "400Gi"
}

variable "ami_family" {
  description = "AMI family for Karpenter EC2NodeClass (AL2 | AL2023 | Bottlerocket)"
  type        = string
  default     = "AL2023"
}

# ── Addons ────────────────────────────────────────────────────────────────────
variable "alb_controller_version" {
  description = "AWS Load Balancer Controller Helm chart version"
  type        = string
  default     = "1.7.2"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.14.4"
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID used by cert-manager + external-dns"
  type        = string
  default     = ""
}

variable "external_dns_version" {
  description = "external-dns Helm chart version"
  type        = string
  default     = "1.14.4"
}

variable "external_dns_domain" {
  description = "DNS domain external-dns manages (e.g. example.com)"
  type        = string
  default     = ""
}

variable "ebs_csi_driver_version" {
  description = "EBS CSI Driver Helm chart version"
  type        = string
  default     = "2.29.0"
}

variable "metrics_server_version" {
  description = "metrics-server Helm chart version"
  type        = string
  default     = "3.12.1"
}
