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

# --- eda (ed8 variant) dedicated tunnel ---

output "eda_tunnel_id" {
  description = "Cloudflare Tunnel ID for the dedicated eda tunnel (eda-edatw)"
  value       = module.eda_tunnel.tunnel_id
}

output "eda_tunnel_token" {
  description = "Tunnel token for the eda cloudflared connector (edatw-lab). Store in the edatw-eda SOPS secret cloudflared-eda-credentials."
  value       = module.eda_tunnel.tunnel_token
  sensitive   = true
}

# --- OpenClaw dedicated tunnel ---
# NOTE: Cloudflare Access was removed (it blocked OpenClaw device/node pairing).
# Auth is now OpenClaw's own gateway token (config.raw gateway.auth in
# argocd/edatw-openclaw). The tunnel still exposes openclaw.eda-tw.com publicly.

output "openclaw_tunnel_id" {
  description = "Cloudflare Tunnel ID for the dedicated OpenClaw tunnel (openclaw-edatw)"
  value       = module.openclaw_tunnel.tunnel_id
}

output "openclaw_tunnel_token" {
  description = "Tunnel token for the OpenClaw cloudflared connector (edatw-lab). Store in the edatw-openclaw SOPS secret."
  value       = module.openclaw_tunnel.tunnel_token
  sensitive   = true
}
