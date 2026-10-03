ephemeral "random_password" "restic" {
  length  = 40
  special = false
}

resource "vault_kv_secret_v2" "backup" {
  mount        = var.applications_mount_path
  name         = "healthiermo/backup"
  disable_read = true
  data_json_wo = jsonencode({
    resticPassword = ephemeral.random_password.restic.result
  })
  data_json_wo_version = 1
  lifecycle {
    prevent_destroy = true
  }
}
