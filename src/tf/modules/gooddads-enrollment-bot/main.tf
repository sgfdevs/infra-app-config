locals {
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"

  # Incrementing the Laravel version rotates the encryption key.
  staging_laravel_secret_version       = 1
  staging_neon_secret_version          = 1
  staging_dropbox_secret_version       = 1
  staging_oauth_secret_version         = 1
  staging_sentry_secret_version        = 1
  staging_notifications_secret_version = 1
  staging_ses_secret_version           = 1
}

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "gooddads_enrollment_bot_staging_ses" {
  name = "gooddads-enrollment-bot-staging-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "gooddads-enrollment-bot"
    Environment    = "staging"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "staging-gooddads-enrollment-bot@sgf.dev"
  }
}

resource "aws_iam_user_policy_attachment" "gooddads_enrollment_bot_staging_ses" {
  user       = aws_iam_user.gooddads_enrollment_bot_staging_ses.name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "gooddads_enrollment_bot_staging_ses" {
  user       = aws_iam_user.gooddads_enrollment_bot_staging_ses.name
  depends_on = [aws_iam_user_policy_attachment.gooddads_enrollment_bot_staging_ses]
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_ses" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.gooddads_enrollment_bot_staging_ses.id
    password = aws_iam_access_key.gooddads_enrollment_bot_staging_ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.staging_ses_secret_version
}

ephemeral "random_bytes" "gooddads_enrollment_bot_staging_app_key" {
  length = 32
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_laravel" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/laravel"
  disable_read = true
  data_json_wo = jsonencode({
    appKey = "base64:${ephemeral.random_bytes.gooddads_enrollment_bot_staging_app_key.base64}"
  })
  data_json_wo_version = local.staging_laravel_secret_version
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_neon" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/neon"
  disable_read = true
  data_json_wo = jsonencode({
    neonBaseUrl = "CHANGEME"
    neonApiKey  = "CHANGEME"
  })
  data_json_wo_version = local.staging_neon_secret_version
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_dropbox" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/dropbox"
  disable_read = true
  data_json_wo = jsonencode({
    dropboxAppKey    = "CHANGEME"
    dropboxAppSecret = "CHANGEME"
  })
  data_json_wo_version = local.staging_dropbox_secret_version
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_oauth" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/oauth"
  disable_read = true
  data_json_wo = jsonencode({
    dropboxOauthBasicUser     = "CHANGEME"
    dropboxOauthBasicPassword = "CHANGEME"
  })
  data_json_wo_version = local.staging_oauth_secret_version
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_sentry" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/sentry"
  disable_read = true
  data_json_wo = jsonencode({
    sentryDsn = "CHANGEME"
  })
  data_json_wo_version = local.staging_sentry_secret_version
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_notifications" {
  mount        = var.applications_mount_path
  name         = "gooddads-enrollment-bot/staging/notifications"
  disable_read = true
  data_json_wo = jsonencode({
    mailIntakeFormRecipient = "CHANGEME"
  })
  data_json_wo_version = local.staging_notifications_secret_version
}

resource "vault_policy" "gooddads_enrollment_bot_staging" {
  name   = "gooddads-enrollment-bot-staging"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/laravel" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/neon" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/dropbox" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/oauth" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/sentry" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/notifications" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/ses" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "gooddads_enrollment_bot_staging" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "gooddads-enrollment-bot-staging"
  bound_service_account_names      = ["gooddads-enrollment-bot-secrets"]
  bound_service_account_namespaces = ["gooddads-enrollment-bot-staging"]
  audience                         = "vault"
  token_policies                   = [vault_policy.gooddads_enrollment_bot_staging.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
