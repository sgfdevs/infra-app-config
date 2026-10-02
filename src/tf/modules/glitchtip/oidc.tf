data "zitadel_organizations" "default" {
  is_default = true
}

resource "zitadel_project" "glitchtip" {
  name                   = "GlitchTip"
  org_id                 = one(data.zitadel_organizations.default.ids)
  project_role_assertion = false
  project_role_check     = true
  has_project_check      = false
}

resource "zitadel_project_role" "access" {
  org_id       = one(data.zitadel_organizations.default.ids)
  project_id   = zitadel_project.glitchtip.id
  role_key     = "access"
  display_name = "GlitchTip Access"
  group        = "GlitchTip"
}

resource "zitadel_application_oidc" "web" {
  project_id                  = zitadel_project.glitchtip.id
  org_id                      = one(data.zitadel_organizations.default.ids)
  name                        = "GlitchTip"
  redirect_uris               = ["${local.application_url}/accounts/oidc/zitadel/login/callback/"]
  response_types              = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types                 = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
  app_type                    = "OIDC_APP_TYPE_WEB"
  auth_method_type            = "OIDC_AUTH_METHOD_TYPE_NONE"
  access_token_type           = "OIDC_TOKEN_TYPE_BEARER"
  access_token_role_assertion = false
  id_token_role_assertion     = false
  id_token_userinfo_assertion = true
  post_logout_redirect_uris   = [local.application_url]
  version                     = "OIDC_VERSION_1_0"
  # Only for the localhost HTTP callback. The application enforces PKCE.
  dev_mode = true
}

resource "vault_kv_secret_v2" "oidc" {
  mount        = var.applications_mount_path
  name         = "glitchtip/oidc"
  disable_read = true
  data_json_wo = jsonencode({
    clientId     = zitadel_application_oidc.web.client_id
    discoveryUrl = "https://${var.zitadel_domain}/.well-known/openid-configuration"
  })
  data_json_wo_version = local.secret_version
}
