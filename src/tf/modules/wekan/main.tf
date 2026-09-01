locals {
  application_url = "https://projects.sgf.dev"

  secret_versions = {
    oidc    = 1
    runtime = 1
  }

  # Set this to false after the first apply creates and stores the client secret.
  bootstrap_oidc_client_secret = false
  rotate_oidc_client_secret    = false
}

ephemeral "random_password" "mongodb" {
  length  = 48
  special = false
}

data "zitadel_organizations" "default" {
  is_default = true
}

resource "vault_policy" "secrets" {
  name   = "wekan-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/wekan/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "wekan-secrets"
  bound_service_account_names      = ["wekan-secrets"]
  bound_service_account_namespaces = ["wekan"]
  token_policies                   = [vault_policy.secrets.name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}

resource "zitadel_project" "wekan" {
  name                   = "Wekan"
  org_id                 = one(data.zitadel_organizations.default.ids)
  project_role_assertion = false
  project_role_check     = true
  has_project_check      = false
}

resource "zitadel_project_role" "access" {
  org_id       = one(data.zitadel_organizations.default.ids)
  project_id   = zitadel_project.wekan.id
  role_key     = "access"
  display_name = "Wekan Access"
  group        = "Wekan"
}

resource "zitadel_application_oidc" "wekan" {
  project_id = zitadel_project.wekan.id
  org_id     = one(data.zitadel_organizations.default.ids)

  name                        = "Wekan"
  redirect_uris               = ["${local.application_url}/_oauth/oidc"]
  access_token_role_assertion = false
  additional_origins          = []
  response_types = [
    "OIDC_RESPONSE_TYPE_CODE",
  ]
  grant_types = [
    "OIDC_GRANT_TYPE_AUTHORIZATION_CODE",
  ]
  post_logout_redirect_uris    = [local.application_url]
  app_type                     = "OIDC_APP_TYPE_WEB"
  auth_method_type             = local.bootstrap_oidc_client_secret ? "OIDC_AUTH_METHOD_TYPE_NONE" : "OIDC_AUTH_METHOD_TYPE_BASIC"
  version                      = "OIDC_VERSION_1_0"
  dev_mode                     = false
  id_token_role_assertion      = false
  id_token_userinfo_assertion  = false
  skip_native_app_success_page = false
}

ephemeral "zitadel_application_oidc_client_secret" "wekan" {
  count = local.bootstrap_oidc_client_secret || local.rotate_oidc_client_secret ? 1 : 0

  project_id = zitadel_application_oidc.wekan.project_id
  app_id     = zitadel_application_oidc.wekan.id
  org_id     = zitadel_application_oidc.wekan.org_id
}

resource "vault_kv_secret_v2" "oidc" {
  mount        = var.applications_mount_path
  name         = "wekan/oidc"
  disable_read = true
  data_json_wo = jsonencode({
    clientId     = zitadel_application_oidc.wekan.client_id
    clientSecret = one(ephemeral.zitadel_application_oidc_client_secret.wekan[*].client_secret)
    discoveryUrl = "https://${var.zitadel_domain}/.well-known/openid-configuration"
  })
  data_json_wo_version = local.secret_versions.oidc
}

resource "vault_kv_secret_v2" "runtime" {
  mount        = var.applications_mount_path
  name         = "wekan/runtime"
  disable_read = true
  data_json_wo = jsonencode({
    mongodbPassword = ephemeral.random_password.mongodb.result
  })
  data_json_wo_version = local.secret_versions.runtime
}
