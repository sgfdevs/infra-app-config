ephemeral "random_password" "oidc_client" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "oidc" {
  mount        = var.applications_mount_path
  name         = "glitchtip/oidc"
  disable_read = true
  data_json_wo = jsonencode({
    clientSecret = ephemeral.random_password.oidc_client.result
  })
  data_json_wo_version = local.secret_version
  lifecycle {
    prevent_destroy = true
  }
}

# Dex can only read the shared client secret, not other application credentials.
resource "vault_policy" "dex_client" {
  name   = "glitchtip-dex-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/glitchtip/oidc" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "dex_client" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "glitchtip-dex-secrets"
  bound_service_account_names      = ["glitchtip-dex-secrets"]
  bound_service_account_namespaces = ["dex"]
  audience                         = "vault"
  token_policies                   = [vault_policy.dex_client.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
