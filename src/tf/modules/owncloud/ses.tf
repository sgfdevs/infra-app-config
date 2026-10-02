locals {
  ses_sender         = "files@sgf.dev"
  ses_policy_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
  ses_secret_version = 1
}

resource "aws_iam_user" "ses" {
  name = "owncloud-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "ownCloud"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = local.ses_sender
  }
}

resource "aws_iam_user_policy_attachment" "ses" {
  user       = aws_iam_user.ses.name
  policy_arn = local.ses_policy_arn
}

resource "aws_iam_access_key" "ses" {
  user = aws_iam_user.ses.name

  depends_on = [aws_iam_user_policy_attachment.ses]
}

resource "vault_kv_secret_v2" "ses" {
  mount        = var.applications_mount_path
  name         = "owncloud/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.ses.id
    password = aws_iam_access_key.ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.ses_secret_version
}
