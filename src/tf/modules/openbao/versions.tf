terraform {
  required_version = ">= 1.12"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}
