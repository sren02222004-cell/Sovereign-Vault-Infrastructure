#!/bin/bash
# Sovereign Vault - 納品用全自動デプロイスクリプト（完全修正版）

# 1. 環境初期化
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform

# 2. main.tf の生成
cat << 'EOF' > main.tf
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    # 【修正済】実際のバケット名と完全に一致させた
    bucket         = "sovereign-vault-state-bucket"
    key            = "sovereign-vault/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" { region = "ap-northeast-1" }
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vault_key" {
  description = "Sovereign Vault Master Key"
  enable_key_rotation = true
  multi_region = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "AllowRoot", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }, Action = "kms:*", Resource = "*" },
      { Sid = "PreventCryptoShredding", Effect = "Deny", Principal = "*", Action = ["kms:ScheduleKeyDeletion", "kms:DisableKey"], Resource = "*" }
    ]
  })
}

resource "random_id" "vault_id" { byte_length = 4 }

resource "aws_s3_bucket" "primary" {
  bucket = "sovereign-vault-tokyo-${random_id.vault_id.hex}"
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary_sse" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.vault_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "primary_lock" {
  bucket = aws_s3_bucket.primary.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 3650
    }
  }
}

resource "aws_s3_bucket_policy" "primary_bucket_policy" {
  bucket = aws_s3_bucket.primary.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "EnforceTLSRequestsOnly", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.primary.arn, "${aws_s3_bucket.primary.arn}/*"], Condition = { Bool = { "aws:SecureTransport": "false" } } }
    ]
  })
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "sovereign-vault-logs-${random_id.vault_id.hex}"
}

resource "aws_cloudtrail" "vault_trail" {
  name = "sovereign-vault-trail-${random_id.vault_id.hex}"
  s3_bucket_name = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  is_multi_region_trail = true
  enable_log_file_validation = true
  event_selector {
    read_write_type = "All"
    include_management_events = true
    data_resource { type = "AWS::S3::Object"; values = ["${aws_s3_bucket.primary.arn}/"] }
  }
}
EOF

# 3. 着火
terraform init
terraform apply -auto-approve
