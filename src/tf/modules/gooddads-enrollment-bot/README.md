# Good Dads enrollment bot staging

This module manages staging secrets and OpenBao access. The staging hostname is
`gooddads-enrollment-bot-staging.opensgf.org`. Kubernetes mappings live in
`sgfdevs/infra-k8s-apps/src/k8s/apps/gooddads-enrollment-bot/`.

## Separate OpenBao secrets

Paths below are relative to the KV v2 mount `applications`. Each document has its own
write-only version counter. The policy grants read access to these exact paths.

| Path | OpenBao property | Environment variable | Initial value |
| --- | --- | --- | --- |
| `gooddads-enrollment-bot/staging/laravel` | `appKey` | `APP_KEY` | Generated |
| `gooddads-enrollment-bot/staging/neon` | `neonBaseUrl` | `NEON_BASE_URL` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/neon` | `neonApiKey` | `NEON_API_KEY` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/dropbox` | `dropboxAppKey` | `DROPBOX_APP_KEY` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/dropbox` | `dropboxAppSecret` | `DROPBOX_APP_SECRET` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/oauth` | `dropboxOauthBasicUser` | `DROPBOX_OAUTH_BASIC_USER` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/oauth` | `dropboxOauthBasicPassword` | `DROPBOX_OAUTH_BASIC_PASSWORD` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/sentry` | `sentryDsn` | `SENTRY_LARAVEL_DSN` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/notifications` | `mailIntakeFormRecipient` | `MAIL_INTAKE_FORM_RECIPIENT` | `CHANGEME` |
| `gooddads-enrollment-bot/staging/ses` | `username` | `MAIL_USERNAME` | Managed SES credential |
| `gooddads-enrollment-bot/staging/ses` | `password` | `MAIL_PASSWORD` | Managed SES credential |

Use an application image supporting `MAIL_INTAKE_FORM_RECIPIENT`. No source app changes
belong in this module. Dropbox access and refresh tokens are stored by the app in
MySQL, encrypted using `APP_KEY`; they are not placeholders in OpenBao.

## Generated Laravel key

The ephemeral `random_bytes` resource uses a cryptographic random generator to produce
32 bytes. The Laravel document receives `base64:<base64-encoded bytes>` through
`data_json_wo`. The ephemeral bytes and write-only payload are not persisted in the
OpenTofu plan or state. Random provider 3.9.0 or newer is required and is already locked
by this repository.

Ephemeral generation can run again during later plans/applies, but the Vault resource
only writes a new payload on creation or when its write-only version counter changes.
Keep `application_secret_versions.gooddads_enrollment_bot_staging_laravel` at `1`.
An unchanged counter keeps the stored key stable during ordinary applies; generating
an ephemeral candidate does not itself rotate the OpenBao secret.

Incrementing that counter, replacing the resource, or recreating it after state loss
writes a new key. That can make existing encrypted Dropbox tokens, queued jobs and
sessions unreadable. Treat it as an explicit key rotation requiring a recovery plan,
not a routine application release or integration credential change. For an existing
installation, preserve its current key rather than deploying a newly generated one.

## Manual integration setup

1. After an approved initial apply, open `applications` in the OpenBao UI.
2. Edit the `neon`, `dropbox`, `oauth`, `sentry`, and `notifications` documents under
   `gooddads-enrollment-bot/staging/`. Replace their eight `CHANGEME` values with staging
   configuration, preserving all property names in each document. Use an approved test
   mail recipient. If Sentry is unused, set `sentryDsn` to an empty string instead of
   removing the property or leaving `CHANGEME`.
3. Leave the generated `laravel` key and managed `ses` credentials intact.
4. Wait for External Secrets synchronization and restart the workload through the
   approved deployment procedure. Updating a Kubernetes Secret does not update
   environment variables in running containers.

Do not put real values in Git, Terraform variables, command history, or logs.

## Write-only version safety

All documents use `disable_read = true` and `data_json_wo`, so OpenTofu does not read
manually filled values back into state. Keep each entry's `version` in
`staging_placeholder_secrets` unchanged after manual setup. Incrementing it overwrites
only that integration's document with `CHANGEME`; other documents and the Laravel key
are unaffected. Resource recreation also writes placeholders again. A write-only
payload change alone does not trigger an update, so adding a property requires a
coordinated version bump and refilling that document.

The existing SES counter remains independent. None of these counters should be changed
to match the OpenBao KV version number after an operator edits a secret.
