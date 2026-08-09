locals {
  methodconf_ses_senders = {
    production = "website@methodconf.com"
    staging    = "website-staging@methodconf.com"
  }
  methodconf_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/methodconf/MethodConfSESSender"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "methodconf_ses" {
  for_each = local.methodconf_ses_senders

  name = "methodconf-${each.key}-ses-smtp"
  path = "/applications/methodconf/"

  tags = {
    Application    = "methodconf.com"
    Environment    = each.key
    ManagedBy      = "OpenTofu"
    SESFromAddress = each.value
  }
}

resource "aws_iam_user_policy_attachment" "methodconf_ses" {
  for_each = local.methodconf_ses_senders

  user       = aws_iam_user.methodconf_ses[each.key].name
  policy_arn = local.methodconf_ses_policy_arn
}

resource "aws_iam_access_key" "methodconf_ses" {
  for_each = local.methodconf_ses_senders

  user = aws_iam_user.methodconf_ses[each.key].name

  depends_on = [aws_iam_user_policy_attachment.methodconf_ses]
}

resource "vault_kv_secret_v2" "methodconf_ses" {
  for_each = local.methodconf_ses_senders

  mount        = var.applications_mount_path
  name         = "methodconf/${each.key}/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.methodconf_ses[each.key].id
    password = aws_iam_access_key.methodconf_ses[each.key].ses_smtp_password_v4
  })
  data_json_wo_version = local.application_secret_versions.methodconf_ses
}
