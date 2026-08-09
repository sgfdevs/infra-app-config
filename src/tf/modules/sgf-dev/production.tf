resource "vault_policy" "sgf_dev_production" {
  name   = "sgf-dev-production"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/sgf-dev/production/application" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/sgf-dev/production/ses" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/sgf-dev/production/backup" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "sgf_dev_production_application" {
  mount        = var.applications_mount_path
  name         = "sgf-dev/production/application"
  disable_read = true
  data_json_wo = jsonencode({
    azureBlobStorageKey   = "CHANGEME"
    meetupApiClientSecret = "CHANGEME"
    sentryDsn             = "CHANGEME"
  })
  data_json_wo_version = local.application_secret_versions.sgf_dev_production_application
}

ephemeral "random_password" "sgf_dev_production_restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "sgf_dev_production_backup" {
  mount        = var.applications_mount_path
  name         = "sgf-dev/production/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.sgf_dev_production_restic.result
  })
  data_json_wo_version = local.application_secret_versions.sgf_dev_production_backup
}

resource "vault_kubernetes_auth_backend_role" "sgf_dev_production" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "sgf-dev-production"
  bound_service_account_names      = ["sgf-dev-secrets"]
  bound_service_account_namespaces = ["sgf-dev-production"]
  audience                         = "vault"
  token_policies                   = [vault_policy.sgf_dev_production.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
