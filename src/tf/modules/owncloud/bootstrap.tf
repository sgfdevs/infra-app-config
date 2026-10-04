resource "zitadel_machine_user" "bootstrap" {
  org_id            = one(data.zitadel_organizations.default.ids)
  user_name         = "owncloud-bootstrap"
  name              = "ownCloud bootstrap"
  description       = "Provision ownCloud groups, spaces, and group access"
  access_token_type = "ACCESS_TOKEN_TYPE_JWT"

  # Generate once on creation, not on every plan or apply. The provider stores
  # this secret in state; an ephemeral client secret would rotate on evaluation.
  with_secret = true
}

resource "zitadel_user_grant" "bootstrap" {
  org_id     = one(data.zitadel_organizations.default.ids)
  project_id = zitadel_project.owncloud.id
  user_id    = zitadel_machine_user.bootstrap.id
  role_keys  = [zitadel_project_role.roles["admin"].role_key]
}

resource "vault_kv_secret_v2" "bootstrap" {
  mount        = var.applications_mount_path
  name         = "owncloud/bootstrap"
  disable_read = true
  data_json_wo = jsonencode({
    clientId     = zitadel_machine_user.bootstrap.client_id
    clientSecret = zitadel_machine_user.bootstrap.client_secret
    projectId    = zitadel_project.owncloud.id
    tokenUrl     = "https://${var.zitadel_domain}/oauth/v2/token"
  })
  data_json_wo_version = 1

  depends_on = [zitadel_user_grant.bootstrap]
}
