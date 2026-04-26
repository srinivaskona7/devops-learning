# vpc-stub: a teaching-only "VPC" that uses random_pet to simulate IDs.
# In a real module these would be aws_vpc / aws_subnet resources.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

resource "random_pet" "vpc" {
  length    = 2
  separator = "-"
  keepers   = { name = var.name }
}

resource "random_pet" "subnet" {
  count     = var.subnet_count
  length    = 3
  separator = "-"
  keepers   = { name = var.name, idx = count.index }
}
