locals {
  s3_bucket_name  = "sgfdevs-owncloud-files"
  k3s_oidc_issuer = "k8s-oidc.sgf.dev"
}

resource "aws_s3_bucket" "files" {
  bucket = local.s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Application = "ownCloud"
    Environment = "production"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_s3_bucket_versioning" "files" {
  bucket = aws_s3_bucket.files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "files" {
  bucket = aws_s3_bucket.files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "files" {
  bucket                  = aws_s3_bucket.files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "files" {
  bucket = aws_s3_bucket.files.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "files" {
  bucket = aws_s3_bucket.files.id

  # Keep noncurrent versions and delete markers for recovery.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "files" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.files.arn,
      "${aws_s3_bucket.files.arn}/*",
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

resource "aws_s3_bucket_policy" "files" {
  bucket = aws_s3_bucket.files.id
  policy = data.aws_iam_policy_document.files.json
}

resource "aws_iam_role" "owncloud" {
  name                 = "sgfdevs-k3s-owncloud"
  path                 = "/sgfdevs-k3s/"
  description          = "Allow ownCloud to manage file contents in its private S3 bucket"
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
          "${local.k3s_oidc_issuer}:sub" = "system:serviceaccount:owncloud:owncloud"
        }
      }
    }]
  })

  tags = {
    KubernetesNamespace      = "owncloud"
    KubernetesServiceAccount = "owncloud"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-app-config"
  }
}

resource "aws_iam_role_policy" "files" {
  name = "ManageOwnCloudFiles"
  role = aws_iam_role.owncloud.id

  # No DeleteObjectVersion or versioning administration permissions.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.files.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "${aws_s3_bucket.files.arn}/*"
      },
    ]
  })
}
