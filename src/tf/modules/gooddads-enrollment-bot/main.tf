locals {
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"

  application_secret_versions = {
    gooddads_enrollment_bot_staging_ses = 1
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

resource "vault_policy" "gooddads_enrollment_bot_staging" {
  name   = "gooddads-enrollment-bot-staging"
  policy = <<-EOT
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
