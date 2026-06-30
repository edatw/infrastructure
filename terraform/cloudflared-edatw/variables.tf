# Salary Mailman Environment Variables

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read, Tunnel:Edit, and Access: Apps and Policies:Edit + Access: Service Tokens:Edit permissions"
  type        = string
  sensitive   = true
}

variable "openclaw_allowed_emails" {
  description = "Email addresses allowed to log in to OpenClaw via Cloudflare Access (interactive browser login). The agent service token is always allowed in addition to these."
  type        = list(string)

  validation {
    condition     = length(var.openclaw_allowed_emails) > 0
    error_message = "Set at least one email for human (browser) access to OpenClaw; an empty list would leave only the agent service token able to authenticate."
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for shangkuei.xyz"
  type        = string
}
