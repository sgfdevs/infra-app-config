# ownCloud configuration

## Bootstrap credentials

The module creates a ZITADEL machine user named `owncloud-bootstrap` with JWT
access tokens and the ownCloud project's `admin` role. It grants no ZITADEL
organization or instance administrator permissions.

The machine user's client ID and secret are generated once at creation. They are
stored at `owncloud/bootstrap` in the application secrets mount, alongside:

- `projectId`: the ownCloud ZITADEL project ID.
- `tokenUrl`: the ZITADEL token endpoint.

A future bootstrap Job can read `clientId` and `clientSecret` through an
ExternalSecret and request short-lived tokens with `grant_type=client_credentials`.
Include `openid profile urn:zitadel:iam:org:project:id:<projectId>:aud` in the
requested scope.

These resources provision credentials only. The existing token action still
handles only the web client, and ownCloud's proxy accepts only the web client's
audience. Machine-token claims, audience acceptance, and UserInfo compatibility
must be configured before these tokens can call ownCloud. This module does not
create the Kubernetes Job, groups, or spaces.

The OpenBao payload is write-only, but the ZITADEL provider stores the generated
client secret in Terraform state. Protect state access accordingly. Do not
replace the machine user just to rotate its secret; doing so changes its identity.
Do not switch to an unconditional ephemeral client-secret resource either, since
evaluating it rotates the secret. When intentionally publishing replacement
credentials, increment the bootstrap secret's `data_json_wo_version`.

## Local checks

From the repository root, run `make tf-format`, `make tf-validate`, and:

```sh
tofu -chdir=src/tf test -filter=tests/owncloud-bootstrap.tftest.hcl
```

The test plans the ownCloud module with mocked providers and does not contact
ZITADEL, OpenBao, or AWS.
