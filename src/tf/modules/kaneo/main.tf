locals {
  application_url = "https://projects.sgf.dev"
  s3_bucket_name  = "sgfdevs-kaneo-assets"

  k3s_oidc_issuer        = "k8s-oidc.sgf.dev"
  k3s_workload_role_name = "sgfdevs-k3s-kaneo"

  secret_versions = {
    app  = 1
    oidc = 1
  }

  # Set this to false after the first apply creates and stores the client secret.
  bootstrap_oidc_client_secret = true
  rotate_oidc_client_secret    = false
}

data "zitadel_organizations" "default" {
  is_default = true
}

ephemeral "random_password" "auth" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "kaneo/app"
  disable_read = true
  data_json_wo = jsonencode({
    authSecret = ephemeral.random_password.auth.result
  })
  data_json_wo_version = local.secret_versions.app
}

resource "vault_policy" "secrets" {
  name   = "kaneo-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/kaneo/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "kaneo-secrets"
  bound_service_account_names      = ["kaneo-secrets"]
  bound_service_account_namespaces = ["kaneo"]
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}

resource "zitadel_project" "kaneo" {
  name                   = "Kaneo"
  org_id                 = one(data.zitadel_organizations.default.ids)
  project_role_assertion = false
  project_role_check     = true
  has_project_check      = false
}

resource "zitadel_project_role" "access" {
  org_id       = one(data.zitadel_organizations.default.ids)
  project_id   = zitadel_project.kaneo.id
  role_key     = "access"
  display_name = "Kaneo Access"
  group        = "Kaneo"
}

resource "zitadel_application_oidc" "kaneo" {
  project_id = zitadel_project.kaneo.id
  org_id     = one(data.zitadel_organizations.default.ids)

  name                        = "Kaneo"
  redirect_uris               = ["${local.application_url}/api/auth/oauth2/callback/custom"]
  access_token_role_assertion = false
  additional_origins          = []
  response_types = [
    "OIDC_RESPONSE_TYPE_CODE",
  ]
  grant_types = [
    "OIDC_GRANT_TYPE_AUTHORIZATION_CODE",
  ]
  post_logout_redirect_uris    = [local.application_url]
  app_type                     = "OIDC_APP_TYPE_WEB"
  auth_method_type             = local.bootstrap_oidc_client_secret ? "OIDC_AUTH_METHOD_TYPE_NONE" : "OIDC_AUTH_METHOD_TYPE_BASIC"
  version                      = "OIDC_VERSION_1_0"
  dev_mode                     = false
  id_token_role_assertion      = false
  id_token_userinfo_assertion  = false
  skip_native_app_success_page = false
}

ephemeral "zitadel_application_oidc_client_secret" "kaneo" {
  count = local.bootstrap_oidc_client_secret || local.rotate_oidc_client_secret ? 1 : 0

  project_id = zitadel_application_oidc.kaneo.project_id
  app_id     = zitadel_application_oidc.kaneo.id
  org_id     = zitadel_application_oidc.kaneo.org_id
}

resource "vault_kv_secret_v2" "oidc" {
  mount        = var.applications_mount_path
  name         = "kaneo/oidc"
  disable_read = true
  data_json_wo = jsonencode({
    clientId     = zitadel_application_oidc.kaneo.client_id
    clientSecret = one(ephemeral.zitadel_application_oidc_client_secret.kaneo[*].client_secret)
    discoveryUrl = "https://${var.zitadel_domain}/.well-known/openid-configuration"
  })
  data_json_wo_version = local.secret_versions.oidc
}

data "aws_caller_identity" "current" {}

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
