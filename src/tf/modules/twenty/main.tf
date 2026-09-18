locals {
  application_url    = "https://crm.sgf.dev"
  app_secret_version = 1
}

data "aws_caller_identity" "current" {}

ephemeral "random_password" "app" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "twenty/app"
  disable_read = true
  data_json_wo = jsonencode({
    appSecret = ephemeral.random_password.app.result
  })
  data_json_wo_version = local.app_secret_version
}

resource "vault_policy" "secrets" {
  name   = "twenty-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/twenty/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "twenty-secrets"
  bound_service_account_names      = ["twenty-secrets"]
  bound_service_account_namespaces = ["twenty"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
