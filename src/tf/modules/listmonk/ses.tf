resource "aws_sesv2_configuration_set" "listmonk" {
  configuration_set_name = "listmonk"

  reputation_options {
    reputation_metrics_enabled = true
  }
  suppression_options {
    suppressed_reasons = ["BOUNCE", "COMPLAINT"]
  }

  tags = {
    Application = "Listmonk"
    Environment = "production"
    ManagedBy   = "OpenTofu"
  }
}

resource "aws_iam_user" "ses" {
  name = "listmonk-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "Listmonk"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = "newsletter@sgf.dev"
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
  name         = "listmonk/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username         = aws_iam_access_key.ses.id
    password         = aws_iam_access_key.ses.ses_smtp_password_v4
    host             = "email-smtp.${data.aws_region.current.region}.amazonaws.com"
    port             = 587
    fromAddress      = aws_iam_user.ses.tags["SESFromAddress"]
    configurationSet = aws_sesv2_configuration_set.listmonk.configuration_set_name
  })
  data_json_wo_version = 1
}
