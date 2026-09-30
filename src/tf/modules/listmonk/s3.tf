locals {
  k3s_oidc_issuer = "k8s-oidc.sgf.dev"
}

resource "aws_s3_bucket" "uploads" {
  bucket = "sgfdevs-listmonk-uploads"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Application = "Listmonk"
    Environment = "production"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "uploads" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.uploads.arn,
      "${aws_s3_bucket.uploads.arn}/*",
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

resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  policy = data.aws_iam_policy_document.uploads.json
}

resource "aws_iam_role" "listmonk" {
  name                 = "sgfdevs-k3s-listmonk"
  path                 = "/sgfdevs-k3s/"
  description          = "Allow Listmonk to manage its private S3 uploads"
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
          "${local.k3s_oidc_issuer}:sub" = "system:serviceaccount:listmonk:listmonk"
        }
      }
    }]
  })

  tags = {
    KubernetesNamespace      = "listmonk"
    KubernetesServiceAccount = "listmonk"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-app-config"
  }
}

resource "aws_iam_role_policy" "uploads" {
  name = "ManageListmonkUploads"
  role = aws_iam_role.listmonk.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}
