variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

variable "node_iam_role_name" {
  description = "IAM role name for EKS nodes (Karpenter assigns this to new instances)"
  type        = string
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "0.37.0"
}

variable "instance_types" {
  description = "Allowed EC2 instance types for the default NodePool"
  type        = list(string)
  default     = [
    "m5.large", "m5.xlarge", "m5.2xlarge",
    "m5a.large", "m5a.xlarge",
    "m6i.large", "m6i.xlarge",
    "m6a.large", "m6a.xlarge",
  ]
}

variable "availability_zones" {
  description = "AZs the NodePool can launch nodes into"
  type        = list(string)
}

variable "nodepool_cpu_limit" {
  description = "Max CPU cores Karpenter can provision across all nodes"
  type        = string
  default     = "100"
}

variable "nodepool_memory_limit" {
  description = "Max memory Karpenter can provision"
  type        = string
  default     = "400Gi"
}

variable "ami_family" {
  description = "AMI family for EC2NodeClass (AL2 | AL2023 | Bottlerocket)"
  type        = string
  default     = "AL2023"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where Karpenter launches nodes"
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all AWS resources"
  type        = map(string)
  default     = {}
}
