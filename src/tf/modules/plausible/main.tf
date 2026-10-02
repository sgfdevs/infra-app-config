locals {
  secret_version = 1
}

ephemeral "random_password" "secret_key_base" {
  length  = 86
  special = false
}

ephemeral "random_password" "totp" {
  length  = 32
  special = true
}

ephemeral "random_password" "clickhouse" {
  length  = 40
  special = false
}

ephemeral "random_password" "restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "plausible/app"
  disable_read = true
  data_json_wo = jsonencode({
    secretKeyBase      = ephemeral.random_password.secret_key_base.result
    totpVaultKey       = base64encode(ephemeral.random_password.totp.result)
    clickhousePassword = ephemeral.random_password.clickhouse.result
  })
  data_json_wo_version = local.secret_version
  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_kv_secret_v2" "backup" {
  mount        = var.applications_mount_path
  name         = "plausible/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.restic.result
  })
  data_json_wo_version = local.secret_version
  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_policy" "secrets" {
  name   = "plausible-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/plausible/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "plausible-secrets"
  bound_service_account_names      = ["plausible-secrets"]
  bound_service_account_namespaces = ["plausible"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
