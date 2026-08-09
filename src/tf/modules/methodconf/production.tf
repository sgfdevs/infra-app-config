resource "vault_policy" "methodconf_production" {
  name   = "methodconf-production"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/methodconf/production/application" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/methodconf/production/ses" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/methodconf/production/backup" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "methodconf_production_application" {
  mount        = var.applications_mount_path
  name         = "methodconf/production/application"
  disable_read = true
  data_json_wo = jsonencode({
    newsletterListId = "CHANGEME"
  })
  data_json_wo_version = local.application_secret_versions.methodconf_production_application
}

ephemeral "random_password" "methodconf_production_restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "methodconf_production_backup" {
  mount        = var.applications_mount_path
  name         = "methodconf/production/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.methodconf_production_restic.result
  })
  data_json_wo_version = local.application_secret_versions.methodconf_production_backup
}

resource "vault_kubernetes_auth_backend_role" "methodconf_production" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "methodconf-production"
  bound_service_account_names      = ["methodconf-secrets"]
  bound_service_account_namespaces = ["methodconf-com-production"]
  audience                         = "vault"
  token_policies                   = [vault_policy.methodconf_production.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
