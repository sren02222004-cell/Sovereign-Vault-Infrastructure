# ==========================================
# Sovereign Vault - 納品用全自動デプロイスクリプト
# ==========================================

# 1. 環境の完全初期化（過去のゴミを消去し、最新の武器を正規ルートで調達）

sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform

# 2. 神の金庫（完全版アーキテクチャ）の流し込み
cat << 'EOF' > main.tf
terraform { required_version = ">= 1.5.0" }
provider "aws" { region = "ap-northeast-1" }
data "aws_caller_identity" "current" {}

# Layer 1: 暗号化基盤（削除禁止特約付き）
resource "aws_kms_key" "vault_key" {
  description             = "Sovereign Vault Master Key"
  enable_key_rotation     = true
  multi_region            = true
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

# Layer 2: 10年ロックの絶対金庫本体
resource "aws_s3_bucket" "primary" {
  bucket              = "sovereign-vault-tokyo-${random_id.vault_id.hex}"
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary_sse" {
  bucket = aws_s3_bucket.primary.id
  rule { apply_server_side_encryption_by_default { kms_master_key_id = aws_kms_key.vault_key.arn; sse_algorithm = "aws:kms" } }
}

resource "aws_s3_bucket_public_access_block" "primary_block" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "primary_lock" {
  bucket = aws_s3_bucket.primary.id
  rule { default_retention { mode = "COMPLIANCE"; days = 3650 } }
}

resource "aws_s3_bucket_policy" "primary_bucket_policy" {
  bucket = aws_s3_bucket.primary.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "EnforceTLSRequestsOnly", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.primary.arn, "${aws_s3_bucket.primary.arn}/*"], Condition = { Bool = { "aws:SecureTransport": "false" } } },
      { Sid = "PreventPolicyTampering", Effect = "Deny", Principal = "*", Action = ["s3:DeleteBucketPolicy", "s3:PutBucketPolicy"], Resource = aws_s3_bucket.primary.arn }
    ]
  })
}

# Layer 3: 監視カメラ（CloudTrail）とログ保管庫
resource "aws_s3_bucket" "log_bucket" {
  bucket = "sovereign-vault-logs-${random_id.vault_id.hex}"
}

resource "aws_s3_bucket_policy" "log_bucket_policy" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid = "AWSCloudTrailAclCheck", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.log_bucket.arn, Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } } },
      { Sid = "AWSCloudTrailWrite", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*", Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceAccount" = data.aws_caller_identity.current.account_id } } }
    ]
  })
}

resource "aws_cloudtrail" "vault_trail" {
  name                          = "sovereign-vault-trail-${random_id.vault_id.hex}"
  s3_bucket_name                = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.log_bucket_policy]
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource { type = "AWS::S3::Object"; values = ["${aws_s3_bucket.primary.arn}/"] }
  }
}
EOF

# 3. 着火（デプロイ）
terraform init
terraform apply -auto-approve
