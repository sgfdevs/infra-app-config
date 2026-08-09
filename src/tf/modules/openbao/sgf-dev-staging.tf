resource "vault_policy" "sgf_dev_staging" {
  name   = "sgf-dev-staging"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/sgf-dev/staging/application" {
      capabilities = ["read"]
    }

    path "${vault_mount.applications.path}/data/sgf-dev/staging/ses" {
      capabilities = ["read"]
    }

    path "${vault_mount.applications.path}/data/sgf-dev/staging/backup" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "sgf_dev_staging_application" {
  mount        = vault_mount.applications.path
  name         = "sgf-dev/staging/application"
  disable_read = true
  data_json_wo = jsonencode({
    azureBlobStorageKey   = "CHANGEME"
    meetupApiClientSecret = "CHANGEME"
    sentryDsn             = "CHANGEME"
  })
  data_json_wo_version = 1
}

ephemeral "random_password" "sgf_dev_staging_restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "sgf_dev_staging_backup" {
  mount        = vault_mount.applications.path
  name         = "sgf-dev/staging/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.sgf_dev_staging_restic.result
  })
  data_json_wo_version = 1
}

resource "vault_kubernetes_auth_backend_role" "sgf_dev_staging" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "sgf-dev-staging"
  bound_service_account_names      = ["sgf-dev-secrets"]
  bound_service_account_namespaces = ["sgf-dev-staging"]
  audience                         = "vault"
  token_policies                   = [vault_policy.sgf_dev_staging.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
