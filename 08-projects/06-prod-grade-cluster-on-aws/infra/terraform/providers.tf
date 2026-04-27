###############################################################################
# Provider configuration
# All providers are version-pinned in versions.tf
###############################################################################

terraform {
  # Backend is configured per-environment via backend-s3.tf (gitignored)
  # Copy backend-s3.tf.example → backend-s3.tf and fill in your bucket details
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "devops-learning/08-projects/06-prod-grade-cluster-on-aws"
    }
  }
}

# Kubernetes provider — uses EKS cluster credentials
# Depends on module.eks outputs; configured after cluster creation
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
  }
}

# Helm provider — deploys charts into EKS
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region
      ]
    }
  }
}
