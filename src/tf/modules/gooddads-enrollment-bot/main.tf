locals {
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"

  application_secret_versions = {
    # Keep fixed: incrementing rotates the key used to encrypt Dropbox tokens and queued jobs.
    gooddads_enrollment_bot_staging_laravel = 1
    gooddads_enrollment_bot_staging_ses     = 1
  }

  # Each version is independent. Incrementing rewrites only that document with CHANGEME.
  staging_placeholder_secrets = {
    neon = {
      version = 1
      data = {
        neonBaseUrl = "CHANGEME"
        neonApiKey  = "CHANGEME"
      }
    }
    dropbox = {
      version = 1
      data = {
        dropboxAppKey    = "CHANGEME"
        dropboxAppSecret = "CHANGEME"
      }
    }
    oauth = {
      version = 1
      data = {
        dropboxOauthBasicUser     = "CHANGEME"
        dropboxOauthBasicPassword = "CHANGEME"
      }
    }
    sentry = {
      version = 1
      data = {
        sentryDsn = "CHANGEME"
      }
    }
    notifications = {
      version = 1
      data = {
        mailIntakeFormRecipient = "CHANGEME"
      }
    }
  }
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
  data_json_wo_version = local.application_secret_versions.gooddads_enrollment_bot_staging_ses
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
  data_json_wo_version = local.application_secret_versions.gooddads_enrollment_bot_staging_laravel
}

resource "vault_kv_secret_v2" "gooddads_enrollment_bot_staging_integrations" {
  for_each = local.staging_placeholder_secrets

  mount                = var.applications_mount_path
  name                 = "gooddads-enrollment-bot/staging/${each.key}"
  disable_read         = true
  data_json_wo         = jsonencode(each.value.data)
  data_json_wo_version = each.value.version
}

resource "vault_policy" "gooddads_enrollment_bot_staging" {
  name   = "gooddads-enrollment-bot-staging"
  policy = <<-EOT
    %{for secret in concat(["laravel"], keys(local.staging_placeholder_secrets), ["ses"])~}
    path "${var.applications_mount_path}/data/gooddads-enrollment-bot/staging/${secret}" {
      capabilities = ["read"]
    }
    %{endfor~}
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
