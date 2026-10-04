terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "chapter07-data-path"
}

variable "athena_scan_cutoff_bytes" {
  type    = number
  default = 10737418240 # 10 GiB
}

resource "aws_s3_bucket" "raw" {
  bucket_prefix = "${var.name}-raw-"
}

resource "aws_s3_bucket" "curated" {
  bucket_prefix = "${var.name}-curated-"
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "curated" {
  bucket = aws_s3_bucket.curated.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "curated" {
  bucket = aws_s3_bucket.curated.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_glue_catalog_database" "analytics" {
  name = replace(var.name, "-", "_")
}

resource "aws_athena_workgroup" "analytics" {
  name = var.name
  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = var.athena_scan_cutoff_bytes
    result_configuration {
      output_location = "s3://${aws_s3_bucket.curated.bucket}/athena-results/"
    }
  }
}

output "raw_bucket" { value = aws_s3_bucket.raw.bucket }
output "curated_bucket" { value = aws_s3_bucket.curated.bucket }
output "glue_database" { value = aws_glue_catalog_database.analytics.name }
