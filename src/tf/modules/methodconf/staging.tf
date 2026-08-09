resource "vault_policy" "methodconf_staging" {
  name   = "methodconf-staging"
  policy = <<-EOT
    path "${var.applications_mount_path}/data/methodconf/staging/application" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/methodconf/staging/ses" {
      capabilities = ["read"]
    }

    path "${var.applications_mount_path}/data/methodconf/staging/backup" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kv_secret_v2" "methodconf_staging_application" {
  mount        = var.applications_mount_path
  name         = "methodconf/staging/application"
  disable_read = true
  data_json_wo = jsonencode({
    newsletterListId = "CHANGEME"
  })
  data_json_wo_version = local.application_secret_versions.methodconf_staging_application
}

ephemeral "random_password" "methodconf_staging_restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "methodconf_staging_backup" {
  mount        = var.applications_mount_path
  name         = "methodconf/staging/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.methodconf_staging_restic.result
  })
  data_json_wo_version = local.application_secret_versions.methodconf_staging_backup
}

resource "vault_kubernetes_auth_backend_role" "methodconf_staging" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "methodconf-staging"
  bound_service_account_names      = ["methodconf-secrets"]
  bound_service_account_namespaces = ["methodconf-com-staging"]
  audience                         = "vault"
  token_policies                   = [vault_policy.methodconf_staging.name]
  token_ttl                        = 900
  token_max_ttl                    = 900
}
