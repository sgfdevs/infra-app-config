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
