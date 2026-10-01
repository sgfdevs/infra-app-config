data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_user" "ses" {
  name = "plausible-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "Plausible"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "plausible@sgf.dev"
  }
}

resource "aws_iam_user_policy_attachment" "ses" {
  user       = aws_iam_user.ses.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
}

resource "aws_iam_access_key" "ses" {
  user       = aws_iam_user.ses.name
  depends_on = [aws_iam_user_policy_attachment.ses]
}

resource "vault_kv_secret_v2" "ses" {
  mount        = var.applications_mount_path
  name         = "plausible/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username    = aws_iam_access_key.ses.id
    password    = aws_iam_access_key.ses.ses_smtp_password_v4
    host        = "email-smtp.${data.aws_region.current.region}.amazonaws.com"
    port        = 587
    fromAddress = aws_iam_user.ses.tags["SESFromAddress"]
  })
  data_json_wo_version = local.secret_version
}
