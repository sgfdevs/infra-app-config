provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address = "https://${var.openbao_host}"
  token   = var.openbao_token
}
