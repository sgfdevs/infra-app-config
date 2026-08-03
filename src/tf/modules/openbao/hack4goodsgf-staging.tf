locals {
  hack4goodsgf_staging_ses_from_address = "hack4good-staging@sgf.dev"
}

resource "aws_iam_user" "hack4goodsgf_staging_ses" {
  name = "hack4goodsgf-staging-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "sgf.dev"
    Environment    = "staging"
    ManagedBy      = "OpenTofu"
    SESFromAddress = local.hack4goodsgf_staging_ses_from_address
  }
}

resource "aws_iam_user_policy_attachment" "hack4goodsgf_staging_ses" {
  user       = aws_iam_user.hack4goodsgf_staging_ses.name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "hack4goodsgf_staging_ses" {
  user = aws_iam_user.hack4goodsgf_staging_ses.name

  depends_on = [aws_iam_user_policy_attachment.hack4goodsgf_staging_ses]
}

resource "vault_kv_secret_v2" "hack4goodsgf_staging_ses" {
  mount        = vault_mount.applications.path
  name         = "hack4goodsgf/staging/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.hack4goodsgf_staging_ses.id
    password = aws_iam_access_key.hack4goodsgf_staging_ses.ses_smtp_password_v4
  })
  data_json_wo_version = 1
}

ephemeral "random_password" "hack4goodsgf_staging_wordpress_admin" {
  length  = 32
  special = true
}

resource "vault_kv_secret_v2" "hack4goodsgf_staging_wordpress_admin" {
  mount        = vault_mount.applications.path
  name         = "hack4goodsgf/staging/wordpress-admin"
  disable_read = true
  data_json_wo = jsonencode({
    username = "hack4good-admin"
    password = ephemeral.random_password.hack4goodsgf_staging_wordpress_admin.result
    email    = "hostmaster@sgf.dev"
  })
  data_json_wo_version = 1
}

resource "vault_policy" "hack4goodsgf_staging" {
  name   = "hack4goodsgf-staging"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/hack4goodsgf/staging/ses" {
      capabilities = ["read"]
    }

    path "${vault_mount.applications.path}/data/hack4goodsgf/staging/wordpress-admin" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "hack4goodsgf_staging" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "hack4goodsgf-staging"
  bound_service_account_names      = ["hack4goodsgf-secrets"]
  bound_service_account_namespaces = ["hack4goodsgf-com-staging"]
  audience                         = "vault"
  token_policies                   = [vault_policy.hack4goodsgf_staging.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
