locals {
  instances = {
    sgfdevs = {
      url    = "https://docs.sgf.dev"
      bucket = "sgfdevs-outline-assets"
      sender = "outline@sgf.dev"
    }
    opensgf = {
      url    = "https://docs.opensgf.org"
      bucket = "opensgf-outline-assets"
      sender = "opensgf-outline@sgf.dev"
    }
  }
  k3s_oidc_issuer = "k8s-oidc.sgf.dev"
}

data "aws_caller_identity" "current" {}

# Existing SECRET_KEY and UTILS_SECRET belong in outline/<instance>/app as
# secretKey and utilsSecret. Import them from the source instance; never rotate
# or generate replacements as part of the migration.
resource "vault_policy" "secrets" {
  for_each = local.instances

  name   = "outline-${each.key}-secrets"
  policy = <<-EOT
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    path "${var.applications_mount_path}/data/outline/${each.key}/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "secrets" {
  for_each = local.instances

  backend                          = var.kubernetes_auth_backend_path
  role_name                        = "outline-${each.key}-secrets"
  bound_service_account_names      = ["outline-secrets"]
  bound_service_account_namespaces = ["outline-${each.key}"]
  audience                         = "vault"
  token_policies                   = [vault_policy.secrets[each.key].name]
  token_no_default_policy          = true
  token_ttl                        = 900
  token_max_ttl                    = 900
}
