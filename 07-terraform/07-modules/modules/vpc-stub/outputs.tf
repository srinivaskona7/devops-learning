output "vpc_id" {
  description = "Simulated VPC ID."
  value       = "vpc-${random_pet.vpc.id}"
}

output "vpc_cidr" {
  value = var.cidr_block
}

output "subnet_ids" {
  description = "Simulated subnet IDs."
  value       = [for s in random_pet.subnet : "subnet-${s.id}"]
}
