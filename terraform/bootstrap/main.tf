data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "state" {
  description             = "Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.state_kms.json
}

data "aws_iam_policy_document" "state_kms" {
  #checkov:skip=CKV_AWS_109:KMS key policies require Resource "*" and access is restricted to the account-root principal.
  #checkov:skip=CKV_AWS_111:KMS key policies require Resource "*" and write access is restricted to the account-root principal.
  #checkov:skip=CKV_AWS_356:KMS key policies require Resource "*" because the key ARN is not available while defining its policy.
  statement {
    sid    = "AccountKeyAdministration"
    effect = "Allow"
    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateAlias",
      "kms:CreateGrant",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListGrants",
      "kms:ListKeyPolicies",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:RevokeGrant",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
      "kms:UpdateKeyDescription"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "StateStorageUse"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values = [
        "dynamodb.${data.aws_region.current.name}.amazonaws.com",
        "s3.${data.aws_region.current.name}.amazonaws.com"
      ]
    }
  }
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally omitted in this single-region simulation to avoid a second-region bucket and replication charges.
  #checkov:skip=CKV2_AWS_62:Event notifications are intentionally omitted because this single-region simulation has no event consumer.
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "state_access_logs" {
  #checkov:skip=CKV_AWS_145:AWS requires S3 server-access-log destination buckets to use SSE-S3 because SSE-KMS can make delivered logs unreadable.
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally omitted in this single-region simulation to avoid a second-region bucket and replication charges.
  #checkov:skip=CKV2_AWS_62:Event notifications are intentionally omitted because this single-region simulation has no event consumer.
  bucket = "${var.state_bucket_name}-access-logs"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  rule {
    id     = "log-retention"
    status = "Enabled"
    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.state_access_logs.id
  target_prefix = "state/"

  depends_on = [aws_s3_bucket_policy.state_access_logs]
}

data "aws_iam_policy_document" "state_access_logs" {
  statement {
    sid     = "S3ServerAccessLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.state_access_logs.arn}/state/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.state.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state_access_logs.arn,
      "${aws_s3_bucket.state_access_logs.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  policy = data.aws_iam_policy_document.state_access_logs.json
}

resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:environment:production"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "github_actions" {
  #checkov:skip=CKV_AWS_107:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  #checkov:skip=CKV_AWS_108:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  #checkov:skip=CKV_AWS_109:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  #checkov:skip=CKV_AWS_110:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  #checkov:skip=CKV_AWS_111:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  #checkov:skip=CKV_AWS_356:Broad provisioning permissions are restricted by repository and branch/environment OIDC claims and permitted only in an isolated sandbox account.
  statement {
    sid = "ManageSimulationInfrastructure"
    actions = [
      "autoscaling:*",
      "cloudwatch:*",
      "dynamodb:*",
      "ec2:*",
      "eks:*",
      "iam:*",
      "kms:*",
      "logs:*",
      "s3:*",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "terraform-provisioner"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
