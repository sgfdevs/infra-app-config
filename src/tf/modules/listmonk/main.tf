data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "vault_policy" "secrets" {
  name   = "listmonk-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/listmonk/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "listmonk-secrets"
  bound_service_account_names      = ["listmonk-secrets"]
  bound_service_account_namespaces = ["listmonk"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
