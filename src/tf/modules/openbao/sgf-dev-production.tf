resource "vault_policy" "sgf_dev_production" {
  name   = "sgf-dev-production"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/sgf-dev/production/application" {
      capabilities = ["read"]
    }

    path "${vault_mount.applications.path}/data/sgf-dev/production/ses" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "sgf_dev_production_application" {
  mount        = vault_mount.applications.path
  name         = "sgf-dev/production/application"
  disable_read = true
  data_json_wo = jsonencode({
    azureBlobStorageKey   = "CHANGEME"
    meetupApiClientSecret = "CHANGEME"
    sentryDsn             = "CHANGEME"
  })
  data_json_wo_version = 1
}

resource "vault_kubernetes_auth_backend_role" "sgf_dev_production" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "sgf-dev-production"
  bound_service_account_names      = ["sgf-dev-secrets"]
  bound_service_account_namespaces = ["sgf-dev-production"]
  audience                         = "vault"
  token_policies                   = [vault_policy.sgf_dev_production.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
