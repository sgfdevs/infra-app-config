locals {
  application_url    = "https://projects.sgf.dev"
  app_secret_version = 1
}

ephemeral "random_password" "auth" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "kaneo/app"
  disable_read = true
  data_json_wo = jsonencode({
    authSecret = ephemeral.random_password.auth.result
  })
  data_json_wo_version = local.app_secret_version
}

resource "vault_policy" "secrets" {
  name   = "kaneo-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/kaneo/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "kaneo-secrets"
  bound_service_account_names      = ["kaneo-secrets"]
  bound_service_account_namespaces = ["kaneo"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
