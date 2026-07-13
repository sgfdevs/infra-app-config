resource "vault_policy" "raft_backup" {
  name   = "raft-backup"
  policy = <<-EOT
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc:443"
}

resource "vault_kubernetes_auth_backend_role" "raft_backup" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "raft-backup"
  bound_service_account_names      = ["openbao-backup"]
  bound_service_account_namespaces = ["openbao"]
  token_policies                   = [vault_policy.raft_backup.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
