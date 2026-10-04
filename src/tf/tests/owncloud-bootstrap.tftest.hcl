mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}
mock_provider "random" {}
mock_provider "vault" {}
mock_provider "zitadel" {
  mock_data "zitadel_organizations" {
    defaults = {
      ids = ["test-org"]
    }
  }
}

run "bootstrap_identity" {
  command = plan

  module {
    source = "./modules/owncloud"
  }

  variables {
    applications_mount_path      = "applications"
    kubernetes_auth_backend_path = "kubernetes"
    zitadel_domain               = "auth.example.com"
  }

  assert {
    condition = (
      zitadel_machine_user.bootstrap.org_id == "test-org" &&
      zitadel_machine_user.bootstrap.user_name == "owncloud-bootstrap" &&
      zitadel_machine_user.bootstrap.access_token_type == "ACCESS_TOKEN_TYPE_JWT" &&
      !zitadel_machine_user.bootstrap.with_secret
    )
    error_message = "Bootstrap must be a JWT machine user with state-backed credential generation disabled."
  }

  assert {
    condition = (
      zitadel_user_grant.bootstrap.org_id == "test-org" &&
      zitadel_user_grant.bootstrap.project_id == zitadel_project.owncloud.id &&
      zitadel_user_grant.bootstrap.user_id == zitadel_machine_user.bootstrap.id &&
      zitadel_user_grant.bootstrap.role_keys == toset(["admin"])
    )
    error_message = "Bootstrap must receive only the ownCloud project's admin role."
  }

  assert {
    condition = (
      vault_kv_secret_v2.bootstrap.mount == "applications" &&
      vault_kv_secret_v2.bootstrap.name == "owncloud/bootstrap" &&
      vault_kv_secret_v2.bootstrap.disable_read &&
      vault_kv_secret_v2.bootstrap.data_json == null &&
      vault_kv_secret_v2.bootstrap.data_json_wo == null &&
      vault_kv_secret_v2.bootstrap.data_json_wo_version == local.bootstrap_secret_version
    )
    error_message = "Bootstrap credentials must use the dedicated write-only OpenBao secret without a state-backed payload."
  }
}
