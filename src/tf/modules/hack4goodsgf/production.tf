locals {
  hack4goodsgf_production_ses_from_address = "hack4good@sgf.dev"
}

resource "aws_iam_user" "hack4goodsgf_production_ses" {
  name = "hack4goodsgf-production-ses-smtp"
  path = "/applications/sgf-dev/"

  tags = {
    Application    = "sgf.dev"
    Environment    = "production"
    ManagedBy      = "OpenTofu"
    SESFromAddress = local.hack4goodsgf_production_ses_from_address
  }
}

resource "aws_iam_user_policy_attachment" "hack4goodsgf_production_ses" {
  user       = aws_iam_user.hack4goodsgf_production_ses.name
  policy_arn = local.sgf_dev_ses_policy_arn
}

resource "aws_iam_access_key" "hack4goodsgf_production_ses" {
  user = aws_iam_user.hack4goodsgf_production_ses.name

  depends_on = [aws_iam_user_policy_attachment.hack4goodsgf_production_ses]
}

resource "vault_kv_secret_v2" "hack4goodsgf_production_ses" {
  mount        = var.applications_mount_path
  name         = "hack4goodsgf/production/ses"
  disable_read = true
  data_json_wo = jsonencode({
    username = aws_iam_access_key.hack4goodsgf_production_ses.id
    password = aws_iam_access_key.hack4goodsgf_production_ses.ses_smtp_password_v4
  })
  data_json_wo_version = local.application_secret_versions.hack4goodsgf_production_ses
}

ephemeral "random_password" "hack4goodsgf_production_wordpress_admin" {
  length  = 32
  special = true
}

resource "vault_kv_secret_v2" "hack4goodsgf_production_wordpress_admin" {
  mount        = var.applications_mount_path
  name         = "hack4goodsgf/production/wordpress-admin"
  disable_read = true
  data_json_wo = jsonencode({
    username = "hack4good-admin"
    password = ephemeral.random_password.hack4goodsgf_production_wordpress_admin.result
    email    = "hostmaster@sgf.dev"
  })
  data_json_wo_version = local.application_secret_versions.hack4goodsgf_production_wordpress_admin
}

resource "vault_policy" "hack4goodsgf_production" {
  name   = "hack4goodsgf-production"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/hack4goodsgf/production/ses" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/hack4goodsgf/production/wordpress-admin" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "hack4goodsgf_production" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "hack4goodsgf-production"
  bound_service_account_names      = ["hack4goodsgf-secrets"]
  bound_service_account_namespaces = ["hack4goodsgf-com-production"]
  audience                         = "vault"
  token_policies                   = [vault_policy.hack4goodsgf_production.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
