data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

ephemeral "aws_ssm_parameter" "dex_client_secrets" {
  arn = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/dex-client-secrets"
}

resource "vault_policy" "application_secrets_admin" {
  name   = "application-secrets-admin"
  policy = <<-EOT
    path "${vault_mount.applications.path}/data/*" {
      capabilities = ["create", "read", "update", "delete", "patch"]
    }

    path "${vault_mount.applications.path}/metadata" {
      capabilities = ["list"]
    }

    path "${vault_mount.applications.path}/metadata/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "${vault_mount.applications.path}/delete/*" {
      capabilities = ["update"]
    }

    path "${vault_mount.applications.path}/undelete/*" {
      capabilities = ["update"]
    }

    path "${vault_mount.applications.path}/destroy/*" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_jwt_auth_backend" "oidc" {
  description                   = "OIDC auth via SGF Devs Dex (dex.sgf.dev)"
  path                          = "oidc"
  type                          = "oidc"
  oidc_discovery_url            = "https://dex.sgf.dev"
  oidc_client_id                = "openbao"
  oidc_client_secret_wo         = jsondecode(ephemeral.aws_ssm_parameter.dex_client_secrets.value).openbaoClientSecret
  oidc_client_secret_wo_version = 1
  default_role                  = "admin"
  bound_issuer                  = "https://dex.sgf.dev"
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend    = vault_jwt_auth_backend.oidc.path
  role_name  = "admin"
  role_type  = "oidc"
  user_claim = "email"
  bound_claims = {
    groups = "sgfdevs:platform-admins"
  }
  token_policies = ["default", vault_policy.application_secrets_admin.name]
  oidc_scopes    = ["openid", "profile", "email", "groups"]
  allowed_redirect_uris = [
    "https://secrets.sgf.dev/ui/vault/auth/oidc/oidc/callback",
    "https://secrets.sgf.dev/auth/oidc/callback",
  ]
}
