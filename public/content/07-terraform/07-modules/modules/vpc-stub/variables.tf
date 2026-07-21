variable "name" {
  type        = string
  description = "VPC name."
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block."
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  type        = number
  description = "How many subnets to create."
  default     = 2

  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 6
    error_message = "subnet_count must be between 1 and 6."
  }
}
