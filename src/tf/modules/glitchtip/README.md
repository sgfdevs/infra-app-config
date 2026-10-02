# GlitchTip configuration

Creates the application SECRET_KEY, Restic password, SES SMTP credentials,
and scoped OpenBao read policy. Credentials are written through write-only
secret fields.

Dex client registration and GlitchTip OIDC configuration live in infra-k8s-apps.
The private URL is http://localhost:8000, with the callback at
/accounts/oidc/dex/login/callback/. The public client uses S256 PKCE without a
client secret. Dex's existing GitHub connector controls who can sign in.
The first authorized SSO login owns the SGF Devs organization; later users join
as members.

Application and backup keys are protected against destruction. Increment
secret_version only for an intentional rotation, and retain old keys alongside
their backups. Changing SECRET_KEY invalidates sessions and can affect stored
application secrets. Do not rotate it as part of a database restore.

No live configuration is applied by this module's PR. S3 bucket credentials are
managed in Kubernetes by the SeaweedFS operator.
