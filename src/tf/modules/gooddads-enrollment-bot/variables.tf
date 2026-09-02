variable "applications_mount_path" {
  description = "Path of the shared OpenBao application secrets mount"
  type        = string
}

variable "kubernetes_auth_backend_path" {
  description = "Path of the shared OpenBao Kubernetes auth backend"
  type        = string
}
