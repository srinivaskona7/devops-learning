# =============================================================================
# infra/replication/s3-replication.tf
#
# Terraform for S3 Cross-Region Replication (CRR) between:
#   Source:      dr-velero-primary-backup  (us-east-1)
#   Destination: dr-velero-secondary-backup (us-west-2)
#
# This module covers:
#   - Source and destination bucket creation
#   - KMS key per region (independent decryption capability)
#   - Versioning (required for CRR)
#   - Replication configuration with Replication Time Control (RTC)
#   - IAM role for S3 replication
#   - Lifecycle rules for retention management
#   - CloudWatch metrics for replication lag
#
# Apply:
#   terraform init
#   terraform plan -var-file=environments/production.tfvars
#   terraform apply -var-file=environments/production.tfvars
# =============================================================================

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Store state in S3 with DynamoDB locking
  backend "s3" {
    bucket         = "terraform-state-dr-lab"
    key            = "dr/s3-replication/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# ─── Providers ───────────────────────────────────────────────────────────────
# Two provider aliases: one per region

provider "aws" {
  alias  = "primary"
  region = var.primary_region

  default_tags {
    tags = {
      Project     = "disaster-recovery"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = {
      Project     = "disaster-recovery"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "primary_region" {
  description = "AWS region for the source (primary) S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "AWS region for the destination (secondary) S3 bucket"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Deployment environment (production / staging)"
  type        = string
  default     = "production"
}

variable "primary_bucket_name" {
  description = "S3 bucket name for primary backups"
  type        = string
  default     = "dr-velero-primary-backup"
}

variable "secondary_bucket_name" {
  description = "S3 bucket name for secondary backups (CRR destination)"
  type        = string
  default     = "dr-velero-secondary-backup"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups before expiry"
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Days to retain noncurrent object versions"
  type        = number
  default     = 7
}

# ─── Data sources ────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ─── KMS keys ────────────────────────────────────────────────────────────────
# Each region has its own KMS key.
# Replication re-encrypts objects with the destination key.
# The secondary can decrypt independently even if primary KMS is unavailable.

resource "aws_kms_key" "primary_s3" {
  provider                = aws.primary
  description             = "S3 backup encryption key — us-east-1"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 replication service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "primary_s3" {
  provider      = aws.primary
  name          = "alias/dr-s3-primary"
  target_key_id = aws_kms_key.primary_s3.key_id
}

resource "aws_kms_key" "secondary_s3" {
  provider                = aws.secondary
  description             = "S3 backup encryption key — us-west-2"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 replication service to decrypt and re-encrypt"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "secondary_s3" {
  provider      = aws.secondary
  name          = "alias/dr-s3-secondary"
  target_key_id = aws_kms_key.secondary_s3.key_id
}

# ─── Source bucket (us-east-1) ───────────────────────────────────────────────

resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = var.primary_bucket_name

  # Prevent accidental deletion of the backup bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning is REQUIRED for CRR
resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.primary_s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  # Depends on versioning being enabled
  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "backup-retention"
    status = "Enabled"

    # Expire current versions after retention period
    expiration {
      days = var.backup_retention_days
    }

    # Delete noncurrent versions faster (saves cost)
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    # Move objects older than 7 days to S3-IA to reduce storage costs
    # WAL segments and base backups older than 7 days are rarely accessed
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
  }
}

# Enable S3 Metrics for replication lag monitoring
resource "aws_s3_bucket_metric" "primary_replication" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  name     = "ReplicationMetrics"
}

# ─── Destination bucket (us-west-2) ─────────────────────────────────────────

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = var.secondary_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.secondary_s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secondary" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.secondary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  depends_on = [aws_s3_bucket_versioning.secondary]

  rule {
    id     = "backup-retention"
    status = "Enabled"
    expiration {
      days = var.backup_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ─── IAM role for replication ────────────────────────────────────────────────

resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "s3-replication-dr-backups"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  provider = aws.primary
  name     = "s3-replication-policy"
  role     = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read objects from source bucket
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        # Write objects to destination bucket
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      },
      {
        # KMS operations for decryption (source) and encryption (destination)
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.primary_s3.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Encrypt"
        ]
        Resource = aws_kms_key.secondary_s3.arn
      }
    ]
  })
}

# ─── Replication configuration ───────────────────────────────────────────────

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  provider = aws.primary

  # Replication requires versioning to be enabled first
  depends_on = [aws_s3_bucket_versioning.primary]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    # Replicate ALL objects (no prefix filter)
    filter {}

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"

      # Re-encrypt with destination region's KMS key
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.secondary_s3.arn
      }

      # Replication Time Control (RTC):
      # 99.99% of objects replicated within 15 minutes
      # Required for RPO compliance monitoring
      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }

      # Emit CloudWatch metrics for replication lag
      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }

    # Replicate delete markers
    # Without this: a delete on primary leaves the object on secondary
    # which could cause restores to use corrupt/superseded data
    delete_marker_replication {
      status = "Enabled"
    }

    # Replicate existing objects (requires S3 Batch Replication for existing objects;
    # new objects replicate automatically)
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }
}

# ─── Destination bucket policy ───────────────────────────────────────────────
# Allow the replication role to write to the destination

resource "aws_s3_bucket_policy" "secondary_replication" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReplicationWrite"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.replication.arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}

# ─── CloudWatch alarms ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "replication_pending" {
  provider            = aws.primary
  alarm_name          = "s3-replication-pending-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ReplicationPendingOperations"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Average"
  threshold           = 100  # more than 100 pending operations = alert

  dimensions = {
    SourceBucket = aws_s3_bucket.primary.id
    RuleId       = "replicate-all-objects"
  }

  alarm_description = "S3 replication backlog is high — RPO may be at risk"
  alarm_actions     = [var.pagerduty_sns_arn]

  tags = {
    dr.component = "s3-replication"
  }
}

resource "aws_cloudwatch_metric_alarm" "replication_latency" {
  provider            = aws.primary
  alarm_name          = "s3-replication-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReplicationLatency"
  namespace           = "AWS/S3"
  period              = 60
  statistic           = "Maximum"
  threshold           = 900  # 15 minutes in seconds

  dimensions = {
    SourceBucket = aws_s3_bucket.primary.id
    RuleId       = "replicate-all-objects"
  }

  alarm_description = "S3 replication latency exceeded 15 min — RTC SLA breach"
  alarm_actions     = [var.pagerduty_sns_arn]
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "primary_bucket_arn" {
  description = "ARN of the primary S3 backup bucket"
  value       = aws_s3_bucket.primary.arn
}

output "secondary_bucket_arn" {
  description = "ARN of the secondary (CRR destination) S3 backup bucket"
  value       = aws_s3_bucket.secondary.arn
}

output "primary_kms_key_arn" {
  description = "KMS key ARN for primary bucket encryption"
  value       = aws_kms_key.primary_s3.arn
}

output "secondary_kms_key_arn" {
  description = "KMS key ARN for secondary bucket encryption"
  value       = aws_kms_key.secondary_s3.arn
}

output "replication_role_arn" {
  description = "IAM role ARN used by S3 for replication"
  value       = aws_iam_role.replication.arn
}

# Additional variable referenced in alarms
variable "pagerduty_sns_arn" {
  description = "SNS topic ARN for PagerDuty alerts"
  type        = string
  default     = ""
}
