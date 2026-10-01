locals {
  k3s_oidc_issuer            = "k8s-oidc.sgf.dev"
  sgf_dev_media_environments = toset(["production", "staging"])
}

resource "aws_s3_bucket" "media" {
  for_each = local.sgf_dev_media_environments

  bucket = "sgfdevs-sgf-dev-${each.key}-media"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Application = "sgf.dev"
    Environment = each.key
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "media" {
  for_each = aws_s3_bucket.media

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  for_each = aws_s3_bucket.media

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  for_each = aws_s3_bucket.media

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "media" {
  for_each = aws_s3_bucket.media

  bucket = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  for_each = aws_s3_bucket.media

  bucket = each.value.id
  rule {
    id     = "ExpireMediaCache"
    status = "Enabled"
    filter {
      prefix = "cache/"
    }
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.media]
}

data "aws_iam_policy_document" "media" {
  for_each = aws_s3_bucket.media

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      each.value.arn,
      "${each.value.arn}/*",
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

resource "aws_s3_bucket_policy" "media" {
  for_each = aws_s3_bucket.media

  bucket = each.value.id
  policy = data.aws_iam_policy_document.media[each.key].json
}

resource "aws_iam_role" "media" {
  for_each = aws_s3_bucket.media

  name                 = "sgfdevs-k3s-sgf-dev-${each.key}"
  path                 = "/sgfdevs-k3s/"
  description          = "Allow sgf.dev ${each.key} to manage its private S3 media"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/sgfdevs-k3s/SGFDevsK3sApplicationS3WorkloadBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.k3s_oidc_issuer}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.k3s_oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.k3s_oidc_issuer}:sub" = "system:serviceaccount:sgf-dev-${each.key}:sgf-dev-secrets"
        }
      }
    }]
  })

  tags = {
    KubernetesNamespace      = "sgf-dev-${each.key}"
    KubernetesServiceAccount = "sgf-dev-secrets"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-app-config"
  }
}

resource "aws_iam_role_policy" "media" {
  for_each = aws_s3_bucket.media

  name = "ManageSgfDevMedia"
  role = aws_iam_role.media[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = each.value.arn
      },
      {
        Effect = "Allow"
        Action = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
        Resource = [
          "${each.value.arn}/media/*",
          "${each.value.arn}/cache/*",
        ]
      },
    ]
  })
}
