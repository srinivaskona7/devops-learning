# Example: S3 + DynamoDB backend.
# Bucket and table must already exist (bootstrap them out-of-band).

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "my-tf-state-prod"
    key            = "stacks/network/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
    # kms_key_id   = "arn:aws:kms:eu-west-1:111111111111:key/abcd-..."
  }
}
