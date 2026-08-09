data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

ephemeral "aws_ssm_parameter" "dex_openbao_client_secret" {
  arn = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/dex-openbao-client-secret"
}

resource "vault_jwt_auth_backend" "oidc" {
  description                   = "OIDC auth via SGF Devs Dex (dex.sgf.dev)"
  path                          = "oidc"
  type                          = "oidc"
  oidc_discovery_url            = "https://dex.sgf.dev"
  oidc_client_id                = "openbao"
  oidc_client_secret_wo         = ephemeral.aws_ssm_parameter.dex_openbao_client_secret.value
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
