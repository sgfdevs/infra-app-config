resource "vault_policy" "methodconf_production" {
  name   = "methodconf-production"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/methodconf/production/application" {
      capabilities = ["read"]
    }

    path "${vault_mount.applications.path}/data/methodconf/production/ses" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "methodconf_production_application" {
  mount        = vault_mount.applications.path
  name         = "methodconf/production/application"
  disable_read = true
  data_json_wo = jsonencode({
    newsletterListId = "CHANGEME"
  })
  data_json_wo_version = 1
}

resource "vault_kubernetes_auth_backend_role" "methodconf_production" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "methodconf-production"
  bound_service_account_names      = ["methodconf-secrets"]
  bound_service_account_namespaces = ["methodconf-com-production"]
  audience                         = "vault"
  token_policies                   = [vault_policy.methodconf_production.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
