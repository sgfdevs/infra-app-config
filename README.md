# infra-app-config

Manages post-bootstrap configuration for SGF Devs applications.

## Scope

- Configures OpenBao OIDC authentication through Dex.
- Grants `sgfdevs:platform-admins` access to OpenBao.
- Manages the shared `applications` KV v2 secrets mount and application access policies.
- Configures Kubernetes authentication roles for application secrets and K8up raft snapshot backups.
- Manages application-specific secrets and access configuration.
- Creates SES SMTP users and stores their generated credentials in OpenBao.
- Reads the generated OpenBao Dex client secret from AWS SSM Parameter Store.

## Structure

- `src/tf/`: Root OpenTofu stack and provider configuration.
- `src/tf/modules/openbao/`: Shared application mount, OIDC, Kubernetes auth, and raft backup configuration.
- `src/tf/modules/<application>/`: Application-owned secrets, policies, Kubernetes roles, and supporting resources.
- `.github/workflows/`: Plan, validation, and apply automation.

Secret payloads are write-only. Each application module owns its secret rotation versions in `locals.tf`. Increment a version only when intentionally rotating or replacing that secret payload.

## Run

OpenBao must be initialized, unsealed, and reachable at `https://secrets.sgf.dev`. This stack does not require Headscale connectivity. Set `TF_VAR_openbao_token` to a token authorized to manage the configured resources.

```bash
cp .envrc.example .envrc
make help
make tf-init
make tf-plan
make tf-apply
make tf-output
```

## GitHub Actions Secrets

- `AWS_ROLE_ARN`: SGF Devs GitHub Actions Terraform role ARN.
- `OUTPUT_ENCRYPTION_KEY`: Encryption key used by the reusable plan workflow.
- `TF_VAR_openbao_token`: OpenBao token authorized to manage auth backends, policies, and roles.
