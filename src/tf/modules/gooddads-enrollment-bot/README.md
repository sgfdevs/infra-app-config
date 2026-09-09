# Good Dads enrollment bot staging

This module manages staging secrets and OpenBao access only. The staging hostname is
`gooddads-enrollment-bot-staging.opensgf.org` and the image repository is
`ghcr.io/open-sgf/gooddads-enrollment-bot`, not `glitchedmob`.

## Secret mappings

Paths below are relative to the shared KV v2 mount, `applications`.
Property names are case-sensitive. The deployment must map them to these environment
variables; this module does not configure the deployment.

Application path: `gooddads-enrollment-bot/staging/application`

| OpenBao property | Environment variable | Initial value |
| --- | --- | --- |
| `appKey` | `APP_KEY` | `CHANGEME` |
| `neonBaseUrl` | `NEON_BASE_URL` | `CHANGEME` |
| `neonApiKey` | `NEON_API_KEY` | `CHANGEME` |
| `dropboxAppKey` | `DROPBOX_APP_KEY` | `CHANGEME` |
| `dropboxAppSecret` | `DROPBOX_APP_SECRET` | `CHANGEME` |
| `dropboxOauthBasicUser` | `DROPBOX_OAUTH_BASIC_USER` | `CHANGEME` |
| `dropboxOauthBasicPassword` | `DROPBOX_OAUTH_BASIC_PASSWORD` | `CHANGEME` |
| `sentryDsn` | `SENTRY_LARAVEL_DSN` | `CHANGEME` |
| `mailIntakeFormRecipient` | `MAIL_INTAKE_FORM_RECIPIENT` | `CHANGEME` |

`MAIL_INTAKE_FORM_RECIPIENT` support is in the concurrent source branch
`fix/completed-form-recipient`. Deploy an image containing that support. No source
application changes belong in this module.

Existing SES path: `gooddads-enrollment-bot/staging/ses`

| OpenBao property | Environment variable |
| --- | --- |
| `username` | `MAIL_USERNAME` |
| `password` | `MAIL_PASSWORD` |

OpenTofu manages the SES credentials separately. Do not replace them with application
placeholders. The staging policy grants read access to these two exact secret paths.

## Manual application setup

1. After a separately approved initial apply creates the placeholders, an authorized
   operator opens the `applications` mount in the OpenBao UI and edits
   `gooddads-enrollment-bot/staging/application`.
2. Replace every `CHANGEME` with the staging value, preserving all nine property names.
   Set `mailIntakeFormRecipient` to the intended intake-form recipient. Sentry is
   optional: set `sentryDsn` to an empty string when unused, rather than leaving the
   placeholder or removing the property.
3. Reuse the existing staging Laravel `APP_KEY` if one exists. For a new installation,
   generate a valid Laravel key once using trusted Laravel tooling and store it as
   `appKey`. Keep it stable across restarts and deployments. Changing it can invalidate
   encrypted data and sessions. Do not generate a new key on each deployment.
4. Save all properties together in OpenBao, then use the deployment's normal secret
   synchronization and rollout procedure. Do not put real values in this repository,
   Terraform variables, command history, or logs.

## Write-only version safety

The application resource uses `disable_read = true` and `data_json_wo`. OpenTofu does
not read the manually filled application values back or store that payload in state.

Keep `application_secret_versions.gooddads_enrollment_bot_staging_application` at `1`
after manual fill. Incrementing this counter makes the next apply overwrite all
manual application values with `CHANGEME`. Resource recreation also writes the
placeholders again. Edit operational values in OpenBao, not in `main.tf`, and do not
bump this counter for an application release or a manual secret change.

The application counter is independent of
`application_secret_versions.gooddads_enrollment_bot_staging_ses`. SES changes must
not bump the application counter.
