locals {
  sgf_dev_ses_senders = {
    production = "website@sgf.dev"
    staging    = "website-staging@sgf.dev"
  }
  sgf_dev_ses_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
}

data "aws_caller_identity" "current" {}

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

resource "vault_kv_secret_v2" "sgf_dev_ses" {
  for_each = local.sgf_dev_ses_senders

  mount        = var.applications_mount_path
  name         = "sgf-dev/${each.key}/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.sgf_dev_ses[each.key].id
    password = aws_iam_access_key.sgf_dev_ses[each.key].ses_smtp_password_v4
  })
  data_json_wo_version = local.application_secret_versions.sgf_dev_ses
}
resource "aws_iam_user" "good_dads_production_ses" {
  name = "good-dads-production-ses-smtp"
  path = "/applications/good-dads/"

  tags = {
    Application    = "sgf.dev"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "gooddays-enrolment@sgf.dev"
  }
}

resource "aws_iam_user_policy_attachment" "good_dads_production_ses" {
  user       = aws_iam_user.good_dads_production_ses.name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "good_dads_production_ses" {
  user       = aws_iam_user.good_dads_production_ses.name
  depends_on = [aws_iam_user_policy_attachment.good_dads_production_ses]
}

resource "vault_kv_secret_v2" "good_dads_production_ses" {
  mount        = var.applications_mount_path
  name         = "good-dads/production/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.good_dads_production_ses.id
    password = aws_iam_access_key.good_dads_production_ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.application_secret_versions.good_dads_production_ses
}
