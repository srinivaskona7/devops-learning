terraform {
  required_version = ">= 1.5.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Generate a friendly random name (e.g. "clever-otter").
resource "random_pet" "name" {
  length    = 2
  separator = "-"
}

# Write a local file using that name.
resource "local_file" "hello" {
  filename        = "${path.module}/hello.txt"
  content         = "Hello from ${random_pet.name.id}\n"
  file_permission = "0644"
}

output "pet_name" {
  description = "The randomly generated pet name."
  value       = random_pet.name.id
}

output "file_path" {
  description = "Absolute path of the file we created."
  value       = abspath(local_file.hello.filename)
}
