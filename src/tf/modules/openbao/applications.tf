resource "vault_mount" "applications" {
  path        = "applications"
  type        = "kv"
  description = "Application secrets"

  options = {
    version = "2"
  }
}

resource "vault_policy" "application_secrets_admin" {
  name   = "application-secrets-admin"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/*" {
      capabilities = ["create", "read", "update", "delete", "patch"]
    }

    path "${vault_mount.applications.path}/metadata" {
      capabilities = ["list"]
    }

    path "${vault_mount.applications.path}/metadata/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "${vault_mount.applications.path}/delete/*" {
      capabilities = ["update"]
    }

    path "${vault_mount.applications.path}/undelete/*" {
      capabilities = ["update"]
    }

    path "${vault_mount.applications.path}/destroy/*" {
      capabilities = ["update"]
    }
  EOT
}
