terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type    = string
  default = "europe-west1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "demo" {
  name          = "demo-tf-${random_id.suffix.hex}"
  location      = var.region
  force_destroy = true # allows destroy even if non-empty (lab convenience)

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition { age = 30 }
    action    { type = "Delete" }
  }

  labels = {
    managed_by = "terraform"
    example    = "01-gcs-bucket"
  }
}

output "bucket_url" {
  value = google_storage_bucket.demo.url
}
