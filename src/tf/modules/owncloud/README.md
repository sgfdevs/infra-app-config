# ownCloud configuration

## Bootstrap credentials

The module creates a ZITADEL machine user named `owncloud-bootstrap` with JWT
access tokens and the ownCloud project's `admin` role. It grants no ZITADEL
organization or instance administrator permissions.

The managed machine user has `with_secret = false`. Its credentials are generated
by `ephemeral.zitadel_machine_user_client_secret.bootstrap` and passed directly
to OpenBao's write-only `data_json_wo`. No bootstrap secret material is persisted
in Terraform state or saved plans.

The application secrets path `owncloud/bootstrap` contains `clientId`,
`clientSecret`, `projectId`, and `tokenUrl`. A future bootstrap Job can read
them through an ExternalSecret and request short-lived tokens with
`grant_type=client_credentials`. Include
`openid profile urn:zitadel:iam:org:project:id:<projectId>:aud` in the scope.

## Generation and rotation

The initial configuration enables `local.bootstrap_client_secret` to generate
credentials when the machine user is created. Immediately after the first
successful apply, set it to `false` before running another plan or apply.

The ephemeral resource rotates the ZITADEL secret whenever it is evaluated,
including during planning when its inputs are known. Keep both generation flags
disabled for ordinary plans and applies. Otherwise ZITADEL can rotate the secret
without updating the stored OpenBao payload.

For an intentional rotation:

1. Increment `local.bootstrap_secret_version`.
2. Set `local.rotate_bootstrap_client_secret = true` and apply the change.
3. Set the rotation flag back to `false` before another plan or apply.

Do not advance the secret version with generation disabled; that would publish
null credentials. A failed or abandoned credential-generating plan or apply may
already have rotated the ZITADEL secret. Recover by advancing the version and
performing another explicitly enabled generation, then disable it again.

Do not replace the machine user merely to rotate credentials; replacement changes
its identity. If an earlier state-backed credential was ever applied, this change
does not remove secrets from historical state or plan files. Revoke that
credential and handle retained copies under the state backend's retention policy.

## Scope

These resources provision credentials only. The existing token action still
handles only the web client, and ownCloud's proxy accepts only the web client's
audience. Machine-token claims, audience acceptance, and UserInfo compatibility
must be configured before these tokens can call ownCloud. This module does not
create the Kubernetes Job, groups, or spaces.

## Local checks

From the repository root, run `make tf-format`, `make tf-validate`, and:

```sh
tofu -chdir=src/tf test -filter=tests/owncloud-bootstrap.tftest.hcl
```

The test plans the ownCloud module with mocked providers and does not contact
ZITADEL, OpenBao, or AWS. It checks that managed secret generation and state-backed
OpenBao payloads remain disabled.
