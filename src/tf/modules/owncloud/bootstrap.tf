locals {
  bootstrap_secret_version = 1

  # Initial credentials are provisioned. Keep generation disabled to avoid
  # rotating the secret during ordinary plans and applies.
  bootstrap_client_secret        = false
  rotate_bootstrap_client_secret = false
}

resource "zitadel_machine_user" "bootstrap" {
  org_id            = one(data.zitadel_organizations.default.ids)
  user_name         = "owncloud-bootstrap"
  name              = "ownCloud bootstrap"
  description       = "Provision ownCloud groups, spaces, and group access"
  access_token_type = "ACCESS_TOKEN_TYPE_JWT"

  # Never generate credentials on the managed resource: they would enter state.
  with_secret = false
}

resource "zitadel_user_grant" "bootstrap" {
  org_id     = one(data.zitadel_organizations.default.ids)
  project_id = zitadel_project.owncloud.id
  user_id    = zitadel_machine_user.bootstrap.id
  role_keys  = [zitadel_project_role.roles["admin"].role_key]
}

ephemeral "zitadel_machine_user_client_secret" "bootstrap" {
  count = local.bootstrap_client_secret || local.rotate_bootstrap_client_secret ? 1 : 0

  org_id  = one(data.zitadel_organizations.default.ids)
  user_id = zitadel_machine_user.bootstrap.id

  depends_on = [zitadel_user_grant.bootstrap]
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
  data_json_wo_version = local.bootstrap_secret_version

  depends_on = [zitadel_user_grant.bootstrap]
}
