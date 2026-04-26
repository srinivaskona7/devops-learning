# Example: GCS backend (Google Cloud).
# Bucket must already exist with versioning enabled.

terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "my-tf-state-prod"
    prefix = "stacks/network"
    # GCS provides native locking; no separate lock table needed.
  }
}
