terraform {
  required_version = ">= 1.5.0"
}

variable "project_name" {
  type        = string
  description = "Short name for the project (used in resource names)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be 3-31 chars, lowercase, start with a letter."
  }
}

variable "env" {
  type        = string
  description = "Environment name."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod."
  }
}

variable "region" {
  type        = string
  description = "Cloud region."
  default     = "eu-west-1"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances."

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags applied to every resource."
}

variable "subnet_config" {
  type = map(object({
    cidr_block = string
    public     = bool
  }))
  default = {
    a = { cidr_block = "10.0.1.0/24", public = true }
    b = { cidr_block = "10.0.2.0/24", public = false }
  }
  description = "Subnet definitions keyed by name."
}

variable "db_password" {
  type        = string
  sensitive   = true
  default     = "change-me"
  description = "DB password — provide via TF_VAR_db_password in real usage."
}
