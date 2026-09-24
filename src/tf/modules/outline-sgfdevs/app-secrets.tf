locals {
  secret_key_version   = 1
  utils_secret_version = 1
}

ephemeral "random_password" "secret_key" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "secret_key" {
  mount        = var.applications_mount_path
  name         = "outline/sgfdevs/secret-key"
  disable_read = true
  data_json_wo = jsonencode({
    secretKey = ephemeral.random_password.secret_key.result
  })
  data_json_wo_version = local.secret_key_version
}

ephemeral "random_password" "utils_secret" {
  length  = 64
  special = false
}

resource "vault_kv_secret_v2" "utils_secret" {
  mount        = var.applications_mount_path
  name         = "outline/sgfdevs/utils-secret"
  disable_read = true
  data_json_wo = jsonencode({
    utilsSecret = ephemeral.random_password.utils_secret.result
  })
  data_json_wo_version = local.utils_secret_version
}
