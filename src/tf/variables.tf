variable "aws_region" {
  description = "AWS region for SSM parameters"
  type        = string
  default     = "us-east-2"
}

variable "openbao_host" {
  description = "OpenBao API hostname"
  type        = string
  default     = "secrets.sgf.dev"
}

variable "openbao_token" {
  description = "OpenBao authentication token"
  type        = string
  sensitive   = true
}

variable "zitadel_domain" {
  description = "ZITADEL API hostname"
  type        = string
  default     = "id.sgf.dev"
}

variable "zitadel_jwt_profile_json" {
  description = "ZITADEL machine user JWT profile"
  type        = string
  sensitive   = true
  ephemeral   = true
}
