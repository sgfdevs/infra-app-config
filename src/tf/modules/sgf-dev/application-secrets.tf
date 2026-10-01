resource "vault_kv_secret_v2" "sgf_dev_meetup" {
  for_each = toset(["production", "staging"])

  mount        = var.applications_mount_path
  name         = "sgf-dev/${each.key}/meetup"
  disable_read = true
  data_json_wo = jsonencode({
    meetupApiClientSecret = "CHANGEME"
  })
  data_json_wo_version = local.application_secret_versions.sgf_dev_meetup
}

resource "vault_kv_secret_v2" "sgf_dev_sentry" {
  for_each = toset(["production", "staging"])

  mount        = var.applications_mount_path
  name         = "sgf-dev/${each.key}/sentry"
  disable_read = true
  data_json_wo = jsonencode({
    sentryDsn = "CHANGEME"
  })
  data_json_wo_version = local.application_secret_versions.sgf_dev_sentry
}
