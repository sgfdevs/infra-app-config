locals {
  ses_policy_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/applications/sgf-dev/SgfDevSESSender"
  ses_secret_version = 1
}

# Stock Outline exposes SMTP, not an SES API transport. Each credential is
# restricted to its SESFromAddress tag by the shared sender policy.
resource "aws_iam_user" "ses" {
  for_each = local.instances

  name = "outline-${each.key}-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "Outline-${each.key}"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = each.value.sender
  }
}

resource "aws_iam_user_policy_attachment" "ses" {
  for_each = local.instances

  user       = aws_iam_user.ses[each.key].name
  policy_arn = local.ses_policy_arn
}

resource "aws_iam_access_key" "ses" {
  for_each = local.instances

  user       = aws_iam_user.ses[each.key].name
  depends_on = [aws_iam_user_policy_attachment.ses]
}

resource "vault_kv_secret_v2" "ses" {
  for_each = local.instances

  mount        = var.applications_mount_path
  name         = "outline/${each.key}/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.ses[each.key].id
    password = aws_iam_access_key.ses[each.key].ses_smtp_password_v4
  })
  data_json_wo_version = local.ses_secret_version
}
