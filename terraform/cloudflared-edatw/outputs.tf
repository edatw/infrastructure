# Salary Mailman Environment Outputs

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for salary-mailman"
  value       = module.edatw_tunnel.tunnel_id
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = module.edatw_tunnel.tunnel_name
}

output "tunnel_cname" {
  description = "CNAME target for the tunnel"
  value       = module.edatw_tunnel.tunnel_cname
}

output "tunnel_token" {
  description = "Tunnel token for cloudflared (use in Kubernetes secret)"
  value       = module.edatw_tunnel.tunnel_token
  sensitive   = true
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.edatw_tunnel.dns_records
}

# --- OpenClaw Cloudflare Access ---

output "openclaw_access_app_id" {
  description = "Cloudflare Access application ID protecting openclaw.eda-tw.com"
  value       = cloudflare_zero_trust_access_application.openclaw.id
}

output "openclaw_agent_client_id" {
  description = "Service token Client ID for agents (send as CF-Access-Client-Id header)"
  value       = cloudflare_zero_trust_access_service_token.openclaw_agent.client_id
}

output "openclaw_agent_client_secret" {
  description = "Service token Client Secret for agents (send as CF-Access-Client-Secret header). Only retrievable now — store it securely."
  value       = cloudflare_zero_trust_access_service_token.openclaw_agent.client_secret
  sensitive   = true
}

# --- OpenClaw dedicated tunnel ---

output "openclaw_tunnel_id" {
  description = "Cloudflare Tunnel ID for the dedicated OpenClaw tunnel (openclaw-edatw)"
  value       = module.openclaw_tunnel.tunnel_id
}

output "openclaw_tunnel_token" {
  description = "Tunnel token for the OpenClaw cloudflared connector (edatw-lab). Store in the edatw-openclaw SOPS secret."
  value       = module.openclaw_tunnel.tunnel_token
  sensitive   = true
}
