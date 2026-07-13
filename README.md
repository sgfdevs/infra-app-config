# infra-app-config

Manages post-bootstrap configuration for SGF Devs applications.

## Scope
- Configures OpenBao OIDC authentication through Dex.
- Grants `sgfdevs:platform-admins` access to OpenBao.
- Configures the Kubernetes authentication role and policy used by K8up raft snapshot backups.
- Reads the generated OpenBao Dex client secret from AWS SSM Parameter Store.

This stack does not require Headscale connectivity. OpenBao is reached through `https://secrets.sgf.dev`.

## Bootstrap
OpenBao must be initialized and unsealed before the first apply. Set `TF_VAR_openbao_token` to an initial root token for that apply.

```bash
cp .envrc.example .envrc
make tf-init
make tf-plan
make tf-apply
```

## GitHub Actions secrets
- `AWS_ROLE_ARN`: SGF Devs GitHub Actions Terraform role ARN.
- `OUTPUT_ENCRYPTION_KEY`: Encryption key used by the reusable plan workflow.
- `TF_VAR_openbao_token`: OpenBao token authorized to manage auth backends, policies, and roles.
