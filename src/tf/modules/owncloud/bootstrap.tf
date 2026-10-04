locals {
  machine_secret_version = 1

  # Set this to false after the first apply creates and stores the client secret.
  bootstrap_machine_client_secret = false
  rotate_machine_client_secret    = false
}

resource "zitadel_machine_user" "bootstrap" {
  org_id            = one(data.zitadel_organizations.default.ids)
  user_name         = "owncloud-bootstrap"
  name              = "ownCloud bootstrap"
  description       = "Provision ownCloud groups, spaces, and group access"
  access_token_type = "ACCESS_TOKEN_TYPE_JWT"
  with_secret       = false
}

resource "zitadel_user_grant" "bootstrap" {
  org_id     = one(data.zitadel_organizations.default.ids)
  project_id = zitadel_project.owncloud.id
  user_id    = zitadel_machine_user.bootstrap.id
  role_keys  = [zitadel_project_role.roles["admin"].role_key]
}

ephemeral "zitadel_machine_user_client_secret" "bootstrap" {
  count = local.bootstrap_machine_client_secret || local.rotate_machine_client_secret ? 1 : 0

  org_id  = one(data.zitadel_organizations.default.ids)
  user_id = zitadel_machine_user.bootstrap.id
}

resource "vault_kv_secret_v2" "bootstrap" {
  mount        = var.applications_mount_path
  name         = "owncloud/bootstrap"
  disable_read = true
  data_json_wo = jsonencode({
    clientId     = one(ephemeral.zitadel_machine_user_client_secret.bootstrap[*].client_id)
    clientSecret = one(ephemeral.zitadel_machine_user_client_secret.bootstrap[*].client_secret)
    projectId    = zitadel_project.owncloud.id
    tokenUrl     = "https://${var.zitadel_domain}/oauth/v2/token"
  })
  data_json_wo_version = local.machine_secret_version
}
