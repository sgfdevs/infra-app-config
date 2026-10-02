locals {
  # Keep in sync with the private Kubernetes bootstrap URL.
  application_url = "http://localhost:8000"
  secret_version  = 1
}

ephemeral "random_password" "secret_key" {
  length  = 64
  special = false
}

ephemeral "random_password" "restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "glitchtip/app"
  disable_read = true
  data_json_wo = jsonencode({
    secretKey = ephemeral.random_password.secret_key.result
  })
  data_json_wo_version = local.secret_version
  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_kv_secret_v2" "backup" {
  mount        = var.applications_mount_path
  name         = "glitchtip/backup"
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
  name   = "glitchtip-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/glitchtip/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "glitchtip-secrets"
  bound_service_account_names      = ["glitchtip-secrets"]
  bound_service_account_namespaces = ["glitchtip"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
