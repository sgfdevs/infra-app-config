# GlitchTip configuration

Creates the application SECRET_KEY, Restic password, SES SMTP credentials,
scoped OpenBao read policy, and a Zitadel public web client using authorization
code flow with PKCE. Credentials are written through write-only secret fields.

The private URL is http://localhost:8000. Keep it synchronized with the Kubernetes
configuration and callback at /accounts/oidc/zitadel/login/callback/. Development
mode exists only to permit the localhost HTTP callback.

Grant the GlitchTip project's access role to intended users. The first authorized
SSO login owns the SGF Devs organization; later users join as members.

Application and backup keys are protected against destruction. Increment
secret_version only for an intentional rotation, and retain old keys alongside
their backups. Changing SECRET_KEY invalidates sessions and can affect stored
application secrets. Do not rotate it as part of a database restore.

No live configuration is applied by this module's PR. S3 bucket credentials are
managed in Kubernetes by the SeaweedFS operator.
