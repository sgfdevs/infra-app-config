locals {
  k3s_oidc_issuer = "k8s-oidc.sgf.dev"
}

data "aws_caller_identity" "current" {}

resource "vault_policy" "secrets" {
  name   = "outline-opensgf-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/outline/opensgf/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "outline-opensgf-secrets"
  bound_service_account_names      = ["outline-secrets"]
  bound_service_account_namespaces = ["outline-opensgf"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
