terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    vault = {
      source = "hashicorp/vault"
    }
    zitadel = {
      source = "zitadel/zitadel"
    }
  }
}
