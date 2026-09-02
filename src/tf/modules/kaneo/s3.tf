locals {
  s3_bucket_name = "sgfdevs-kaneo-assets"

  k3s_oidc_issuer        = "k8s-oidc.sgf.dev"
  k3s_workload_role_name = "sgfdevs-k3s-kaneo"
}

resource "aws_s3_bucket" "assets" {
  bucket = local.s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Application = "Kaneo"
    Environment = "production"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = [local.application_url]
    expose_headers  = ["ETag"]
    max_age_seconds = 300
  }
}

data "aws_iam_policy_document" "assets" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*",
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
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets.json
}

resource "aws_iam_role" "kaneo" {
  name                 = local.k3s_workload_role_name
  path                 = "/sgfdevs-k3s/"
  description          = "Allow Kaneo to manage objects in its private S3 bucket"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/sgfdevs-k3s/SGFDevsK3sApplicationS3WorkloadBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.k3s_oidc_issuer}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.k3s_oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.k3s_oidc_issuer}:sub" = "system:serviceaccount:kaneo:kaneo-secrets"
          }
        }
      }
    ]
  })

  tags = {
    KubernetesNamespace      = "kaneo"
    KubernetesServiceAccount = "kaneo-secrets"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-app-config"
  }
}

resource "aws_iam_role_policy" "kaneo_assets" {
  name = "ManageKaneoAssets"
  role = aws_iam_role.kaneo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
    ]
  })
}
