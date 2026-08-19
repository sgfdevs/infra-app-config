variable "aws_region" {
  description = "AWS region for SSM parameters"
  type        = string
  default     = "us-east-2"
}

variable "sgfdevs_aws_account_id" {
  description = "AWS account ID for SGF Devs resources"
  type        = string
}

variable "opensgf_aws_account_id" {
  description = "AWS account ID for OpenSGF resources"
  type        = string
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
