locals {
  # Private bootstrap only. Change this together with the Kubernetes URLs when
  # public ingress is introduced, and remove the localhost redirect URIs.
  application_url    = "http://localhost:9200"
  app_secret_version = 1
}

data "aws_caller_identity" "current" {}

ephemeral "random_password" "passwords" {
  for_each = toset(["idmAdminPassword", "collaboraAdminPassword"])

  length  = 48
  special = false
}

resource "vault_kv_secret_v2" "app" {
  mount        = var.applications_mount_path
  name         = "owncloud/app"
  disable_read = true
  data_json_wo = jsonencode({
    for name, password in ephemeral.random_password.passwords : name => password.result
  })
  data_json_wo_version = local.app_secret_version
}

resource "vault_policy" "secrets" {
  name   = "owncloud-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/owncloud/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "owncloud-secrets"
  bound_service_account_names      = ["owncloud-secrets"]
  bound_service_account_namespaces = ["owncloud"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
