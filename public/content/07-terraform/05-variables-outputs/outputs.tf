locals {
  resource_prefix = "${var.project_name}-${var.env}"

  merged_tags = merge(
    {
      project = var.project_name
      env     = var.env
      managed = "terraform"
    },
    var.tags,
  )
}

output "resource_prefix" {
  value       = local.resource_prefix
  description = "Naming prefix for all resources in this stack."
}

output "merged_tags" {
  value       = local.merged_tags
  description = "Merged tag map (defaults + user)."
}

output "public_subnets" {
  value = {
    for k, v in var.subnet_config : k => v.cidr_block if v.public
  }
  description = "Map of public subnet name -> CIDR."
}

output "db_password_redacted" {
  value       = var.db_password
  sensitive   = true
  description = "Masked in CLI output (still in state file)."
}
