resource "aws_s3_bucket" "assets" {
  for_each = local.instances

  bucket = each.value.bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Application = "Outline-${each.key}"
    Environment = "production"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  for_each = local.instances

  bucket = aws_s3_bucket.assets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  for_each = local.instances

  bucket = aws_s3_bucket.assets[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  for_each = local.instances

  bucket                  = aws_s3_bucket.assets[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  for_each = local.instances

  bucket = aws_s3_bucket.assets[each.key].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_cors_configuration" "assets" {
  for_each = local.instances

  bucket = aws_s3_bucket.assets[each.key].id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST", "PUT"]
    allowed_origins = [each.value.url]
    expose_headers  = ["ETag"]
    max_age_seconds = 300
  }
}

data "aws_iam_policy_document" "assets" {
  for_each = local.instances

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.assets[each.key].arn,
      "${aws_s3_bucket.assets[each.key].arn}/*",
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

resource "aws_s3_bucket_policy" "assets" {
  for_each = local.instances

  bucket = aws_s3_bucket.assets[each.key].id
  policy = data.aws_iam_policy_document.assets[each.key].json
}

resource "aws_iam_role" "outline" {
  for_each = local.instances

  name                 = "sgfdevs-k3s-outline-${each.key}"
  path                 = "/sgfdevs-k3s/"
  description          = "Allow Outline ${each.key} to manage its private S3 assets"
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
          "${local.k3s_oidc_issuer}:sub" = "system:serviceaccount:outline-${each.key}:outline-secrets"
        }
      }
    }]
  })

  tags = {
    KubernetesNamespace      = "outline-${each.key}"
    KubernetesServiceAccount = "outline-secrets"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-app-config"
  }
}

resource "aws_iam_role_policy" "assets" {
  for_each = local.instances

  name = "ManageOutlineAssets"
  role = aws_iam_role.outline[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.assets[each.key].arn}/*"
    }]
  })
}
