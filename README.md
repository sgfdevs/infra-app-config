# infra-app-config

Manages post-bootstrap configuration for SGF Devs applications and shared services.

## Scope
- Owns: configuration applied after application and platform services are deployed.
- Owns: identity, access, integrations, generated credentials, and provider-managed application settings declared in this stack.
- Does not own: foundational infrastructure, DNS, cluster bootstrap, or application deployment.

## Structure
- `src/tf/`: Root OpenTofu stack and provider configuration.
- `src/tf/modules/<service>/`: Configuration grouped by application or shared service.
- `.github/workflows/`: Plan, validation, and apply automation.

## Run
```bash
cp .envrc.example .envrc
make help
make tf-init
make tf-plan
make tf-apply
make tf-output
```

## Operating constraints
- Apply only after the services configured by this stack are initialized and reachable.
- Use `.envrc.example` as the authoritative list of required local credentials. Never commit `.envrc` or secret payloads.
- Secret payloads are write-only where supported. Change module-defined rotation versions only when intentionally replacing those values.
- Treat plans and outputs as sensitive because they may contain application or credential metadata.
