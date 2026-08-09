output "applications_mount_path" {
  description = "Path of the shared application secrets KV mount"
  value       = vault_mount.applications.path
}

output "kubernetes_auth_backend_path" {
  description = "Path of the shared Kubernetes auth backend"
  value       = vault_auth_backend.kubernetes.path
}
