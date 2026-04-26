terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# ---------------------------------------------------------------------------
# Variables — see chapter 05 for full coverage
# ---------------------------------------------------------------------------
variable "env" {
  type        = string
  default     = "dev"
  description = "Environment name."
}

variable "team_members" {
  type        = list(string)
  default     = ["alice", "bob", "carol"]
  description = "List of team member usernames."
}

variable "ports" {
  type    = list(number)
  default = [80, 443, 8080]
}

# ---------------------------------------------------------------------------
# Locals — computed once, reused
# ---------------------------------------------------------------------------
locals {
  common_tags = {
    env   = var.env
    owner = "platform-team"
  }

  # for expression: list -> upper-cased list
  member_files = [for m in var.team_members : "${m}.txt"]

  # for expression: list -> map
  member_index = { for i, m in var.team_members : m => i }
}

# ---------------------------------------------------------------------------
# count — N identical things
# ---------------------------------------------------------------------------
resource "random_pet" "indexed" {
  count     = 3
  length    = 2
  separator = "-"
}

# ---------------------------------------------------------------------------
# for_each (set) — N keyed things, stable identity
# ---------------------------------------------------------------------------
resource "random_pet" "per_member" {
  for_each  = toset(var.team_members)
  length    = 2
  separator = "-"
  keepers   = { member = each.key }
}

# ---------------------------------------------------------------------------
# Conditional + interpolation
# ---------------------------------------------------------------------------
resource "local_file" "greeting" {
  for_each = random_pet.per_member
  filename = "${path.module}/${each.key}.txt"
  content  = <<-EOT
    Hello ${each.key}!
    Your pet is: ${each.value.id}
    Environment: ${var.env}
    Tier: ${var.env == "prod" ? "production" : "non-production"}
  EOT
}

# ---------------------------------------------------------------------------
# Outputs showcasing expressions
# ---------------------------------------------------------------------------
output "indexed_pets" {
  value = [for p in random_pet.indexed : p.id]
}

output "member_pets" {
  value = { for k, v in random_pet.per_member : k => v.id }
}

output "tags" {
  value = local.common_tags
}

output "ports_doubled" {
  value = [for p in var.ports : p * 2]
}
