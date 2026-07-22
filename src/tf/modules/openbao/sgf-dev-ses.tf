locals {
  sgf_dev_ses_senders = {
    production = "website@sgf.dev"
    staging    = "website-staging@sgf.dev"
  }
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
}

resource "aws_iam_user" "sgf_dev_ses" {
  for_each = local.sgf_dev_ses_senders

  name = "sgf-dev-${each.key}-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "sgf.dev"
    Environment    = each.key
    ManagedBy      = "OpenTofu"
    SESFromAddress = each.value
  }
}

resource "aws_iam_user_policy_attachment" "sgf_dev_ses" {
  for_each = local.sgf_dev_ses_senders

  user       = aws_iam_user.sgf_dev_ses[each.key].name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "sgf_dev_ses" {
  for_each = local.sgf_dev_ses_senders

  user = aws_iam_user.sgf_dev_ses[each.key].name

  depends_on = [aws_iam_user_policy_attachment.sgf_dev_ses]
}

resource "vault_mount" "applications" {
  path        = "applications"
  type        = "kv"
  description = "Application secrets"

  options = {
    version = "2"
  }
}

resource "vault_kv_secret_v2" "sgf_dev_ses" {
  for_each = local.sgf_dev_ses_senders

  mount        = vault_mount.applications.path
  name         = "sgf-dev/${each.key}/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.sgf_dev_ses[each.key].id
    password = aws_iam_access_key.sgf_dev_ses[each.key].ses_smtp_password_v4
  })
  data_json_wo_version = 1
}
