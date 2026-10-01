data "zitadel_organizations" "default" {
  is_default = true
}

resource "zitadel_project" "owncloud" {
  name                   = "ownCloud"
  org_id                 = one(data.zitadel_organizations.default.ids)
  project_role_assertion = true
  project_role_check     = true
  has_project_check      = false
}

resource "zitadel_project_role" "roles" {
  for_each = {
    access = "ownCloud Access"
    admin  = "ownCloud Administrator"
  }

  org_id       = one(data.zitadel_organizations.default.ids)
  project_id   = zitadel_project.owncloud.id
  role_key     = each.key
  display_name = each.value
  group        = "ownCloud"
}

resource "zitadel_application_oidc" "web" {
  project_id = zitadel_project.owncloud.id
  org_id     = one(data.zitadel_organizations.default.ids)
  name       = "ownCloud Web"
  redirect_uris = [
    "${local.application_url}/oidc-callback.html",
    "${local.application_url}/oidc-silent-redirect.html",
  ]
  response_types = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types = [
    "OIDC_GRANT_TYPE_AUTHORIZATION_CODE",
    "OIDC_GRANT_TYPE_REFRESH_TOKEN",
  ]
  post_logout_redirect_uris    = [local.application_url, "${local.application_url}/"]
  app_type                     = "OIDC_APP_TYPE_USER_AGENT"
  auth_method_type             = "OIDC_AUTH_METHOD_TYPE_NONE"
  access_token_type            = "OIDC_TOKEN_TYPE_JWT"
  access_token_role_assertion  = true
  id_token_role_assertion      = true
  id_token_userinfo_assertion  = true
  additional_origins           = [local.application_url]
  version                      = "OIDC_VERSION_1_0"
  dev_mode                     = true
  skip_native_app_success_page = false
}

resource "zitadel_action" "owncloud_roles" {
  org_id = one(data.zitadel_organizations.default.ids)
  name   = "owncloudRoles"
  script = templatefile("${path.module}/roles.js.tftpl", {
    client_id  = zitadel_application_oidc.web.client_id
    project_id = zitadel_project.owncloud.id
  })
  timeout         = "5s"
  allowed_to_fail = false
}

resource "zitadel_trigger_actions" "owncloud_roles" {
  for_each = toset([
    "TRIGGER_TYPE_PRE_ACCESS_TOKEN_CREATION",
    "TRIGGER_TYPE_PRE_USERINFO_CREATION",
  ])

  org_id       = one(data.zitadel_organizations.default.ids)
  flow_type    = "FLOW_TYPE_CUSTOMISE_TOKEN"
  trigger_type = each.key
  action_ids   = [zitadel_action.owncloud_roles.id]
}

resource "vault_kv_secret_v2" "oidc" {
  mount        = var.applications_mount_path
  name         = "owncloud/oidc"
  disable_read = true
  data_json_wo = jsonencode({
    clientId = zitadel_application_oidc.web.client_id
    issuer   = "https://${var.zitadel_domain}"
  })
  data_json_wo_version = 1
}
