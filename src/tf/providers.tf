provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.sgfdevs_aws_account_id]
}

provider "aws" {
  alias               = "opensgf"
  region              = var.aws_region
  allowed_account_ids = [var.opensgf_aws_account_id]

  assume_role {
    role_arn     = "arn:aws:iam::${var.opensgf_aws_account_id}:role/SgfdevsAppConfigTerraformRole"
    session_name = "infra-app-config"
  }
}

provider "vault" {
  address = "https://${var.openbao_host}"
  token   = var.openbao_token
}
