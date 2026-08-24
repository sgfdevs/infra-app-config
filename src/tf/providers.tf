provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address = "https://${var.openbao_host}"
  token   = var.openbao_token
}

provider "zitadel" {
  domain           = var.zitadel_domain
  jwt_profile_json = var.zitadel_jwt_profile_json
}
