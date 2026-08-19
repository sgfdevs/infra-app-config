locals {
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "good_dads_staging_ses" {
  name = "good-dads-staging-ses-smtp"
  path = "/applications/good-dads/"

  tags = {
    Application    = "sgf.dev"
    Environment    = "staging"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "gooddays-enrolment@sgf.dev"
  }
}

resource "aws_iam_user_policy_attachment" "good_dads_staging_ses" {
  user       = aws_iam_user.good_dads_staging_ses.name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "good_dads_staging_ses" {
  user       = aws_iam_user.good_dads_staging_ses.name
  depends_on = [aws_iam_user_policy_attachment.good_dads_staging_ses]
}

resource "vault_kv_secret_v2" "good_dads_staging_ses" {
  mount        = var.applications_mount_path
  name         = "good-dads/staging/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.good_dads_staging_ses.id
    password = aws_iam_access_key.good_dads_staging_ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.application_secret_versions.good_dads_staging_ses
}

resource "vault_policy" "good_dads_staging" {
  name   = "good-dads-staging"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/good-dads/staging/ses" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "good_dads_staging" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "good-dads-staging"
  bound_service_account_names      = ["good-dads-secrets"]
  bound_service_account_namespaces = ["good-dads-staging"]
  audience                         = "vault"
  token_policies                   = [vault_policy.good_dads_staging.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
