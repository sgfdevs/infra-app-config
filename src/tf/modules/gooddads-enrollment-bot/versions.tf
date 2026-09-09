terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    vault = {
      source = "hashicorp/vault"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}
