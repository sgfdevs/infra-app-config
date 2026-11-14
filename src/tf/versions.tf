terraform {
  required_version = ">= 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
    zitadel = {
      source  = "zitadel/zitadel"
      version = "~> 3.3"
    }
  }
}
