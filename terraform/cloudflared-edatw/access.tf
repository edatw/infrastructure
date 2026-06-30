# Cloudflare Access (Zero Trust) — front door for OpenClaw
#
# OpenClaw's UI (openclaw.eda-tw.com, routed by the tunnel in main.tf) has no
# built-in authentication and can drive a code-executing agent, so Access is the
# authentication layer. Three client types are supported by one allow-policy:
#   - laptop / mobile browser -> interactive login (email one-time PIN by default;
#     wire an IdP later for SSO) for any address in var.openclaw_allowed_emails
#   - agent / automation       -> the service token below (CF-Access-Client-Id /
#     CF-Access-Client-Secret headers), no browser
#
# Hardening note: Access enforces at Cloudflare's edge. For defense-in-depth,
# have OpenClaw (or an oauth2-proxy sidecar) validate the Cf-Access-Jwt-Assertion
# header so a direct hit on the tunnel origin can't bypass Access.

# Non-interactive credential for agents/automation. client_secret is only
# returned at creation — capture it from the (sensitive) output below.
resource "cloudflare_zero_trust_access_service_token" "openclaw_agent" {
  account_id = var.cloudflare_account_id
  name       = "openclaw-agent"
}

# Reusable allow-policy. include is OR semantics: a caller is allowed if it
# matches ANY entry (one of the listed emails, or the agent service token).
resource "cloudflare_zero_trust_access_policy" "openclaw_allow" {
  account_id = var.cloudflare_account_id
  name       = "openclaw-allow"
  decision   = "allow"

  include = concat(
    [for email in var.openclaw_allowed_emails : { email = { email = email } }],
    [{ service_token = { token_id = cloudflare_zero_trust_access_service_token.openclaw_agent.id } }],
  )
}

# Self-hosted Access application bound to the public hostname. Requests to this
# host must satisfy the policy above before the tunnel forwards them to OpenClaw.
resource "cloudflare_zero_trust_access_application" "openclaw" {
  account_id           = var.cloudflare_account_id
  name                 = "openclaw"
  domain               = "openclaw.eda-tw.com"
  type                 = "self_hosted"
  session_duration     = "24h"
  app_launcher_visible = false

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.openclaw_allow.id
      precedence = 1
    }
  ]
}
