# Salary Mailman Environment Variables

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read, Tunnel:Edit permissions (Access perms no longer needed — OpenClaw Access was removed)"
  type        = string
  sensitive   = true
}

# NOTE: the former `openclaw_allowed_emails` var was dropped with Cloudflare
# Access. If it is still set in the (encrypted) terraform.tfvars, remove it there
# too — an undeclared value only produces a harmless plan/apply warning until then.

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for shangkuei.xyz"
  type        = string
}
