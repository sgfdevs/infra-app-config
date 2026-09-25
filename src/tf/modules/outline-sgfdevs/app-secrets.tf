# The original application keys were restored directly to OpenBao. Preserve them
# when retiring Terraform's temporary, write-only generated values.
removed {
  from = vault_kv_secret_v2.secret_key

  lifecycle {
    destroy = false
  }
}

removed {
  from = vault_kv_secret_v2.utils_secret

  lifecycle {
    destroy = false
  }
}
