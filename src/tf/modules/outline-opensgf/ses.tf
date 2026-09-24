locals {
  ses_policy_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
  ses_secret_version = 1
}

# Stock Outline exposes SMTP, not an SES API transport. The shared sender
# policy restricts these credentials to the SESFromAddress tag.
resource "aws_iam_user" "ses" {
  name = "outline-opensgf-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "Outline-opensgf"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "opensgf-outline@sgf.dev"
  }
}

resource "aws_iam_user_policy_attachment" "ses" {
  user       = aws_iam_user.ses.name
  policy_arn = local.ses_policy_arn
}

resource "aws_iam_access_key" "ses" {
  user       = aws_iam_user.ses.name
  depends_on = [aws_iam_user_policy_attachment.ses]
}

resource "vault_kv_secret_v2" "ses" {
  mount        = var.applications_mount_path
  name         = "outline/opensgf/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.ses.id
    password = aws_iam_access_key.ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.ses_secret_version
}
