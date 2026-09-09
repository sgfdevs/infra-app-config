mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}
mock_provider "vault" {}

variables {
  applications_mount_path      = "applications"
  kubernetes_auth_backend_path = "kubernetes"
}

# Only random_bytes runs locally. AWS and OpenBao are mocked; no secrets are read or written.
run "staging_secret_contract" {
  command = plan

  assert {
    condition = (
      length(ephemeral.random_bytes.gooddads_enrollment_bot_staging_app_key.base64) == 44 &&
      length(ephemeral.random_bytes.gooddads_enrollment_bot_staging_app_key.hex) == 64
    )
    error_message = "Laravel AES-256 requires a base64-encoded 32-byte key."
  }

  assert {
    condition = (
      vault_kv_secret_v2.gooddads_enrollment_bot_staging_laravel.name == "gooddads-enrollment-bot/staging/laravel" &&
      vault_kv_secret_v2.gooddads_enrollment_bot_staging_laravel.disable_read &&
      vault_kv_secret_v2.gooddads_enrollment_bot_staging_laravel.data_json_wo_version == 1
    )
    error_message = "The Laravel key must have its own stable write-only secret."
  }

  assert {
    condition = (
      toset(keys(vault_kv_secret_v2.gooddads_enrollment_bot_staging_integrations)) == toset(["neon", "dropbox", "oauth", "sentry", "notifications"]) &&
      alltrue([for name, secret in vault_kv_secret_v2.gooddads_enrollment_bot_staging_integrations :
        secret.name == "gooddads-enrollment-bot/staging/${name}" && secret.disable_read && secret.data_json_wo_version == 1
      ])
    )
    error_message = "Each integration must have its own write-only document and version."
  }

  assert {
    condition = (
      vault_kv_secret_v2.gooddads_enrollment_bot_staging_ses.name == "gooddads-enrollment-bot/staging/ses" &&
      vault_kv_secret_v2.gooddads_enrollment_bot_staging_ses.data_json_wo_version == 1 &&
      length(regexall("capabilities = \\[\"read\"\\]", vault_policy.gooddads_enrollment_bot_staging.policy)) == 7 &&
      !strcontains(vault_policy.gooddads_enrollment_bot_staging.policy, "/staging/application")
    )
    error_message = "Keep SES unchanged and authorize exactly the seven separate documents."
  }
}
