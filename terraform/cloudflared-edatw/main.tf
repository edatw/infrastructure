# Salary Mailman Application Infrastructure
# Deploys Cloudflare Tunnel and DNS for salary-mailman application

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # 5.21.x. NOTE: upgrading from <=5.12 requires a one-time state migration of
      # cloudflare_zero_trust_tunnel_cloudflared_config (breaking provider state
      # schema). Tight minor pin because provider locks are gitignored here, so the
      # constraint is the only pin guarding against another breaking float.
      version = "~> 5.21.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Deploy salary-mailman Cloudflare Tunnel
module "edatw_tunnel" {
  source = "../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "talos-edatw"

  ingress_rules = [
    {
      hostname = "stage-ed8.eda-tw.com"
      service  = "http://ed8.edatw-ed8.svc.cluster.local:80"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "stage-ed8.eda-tw.com"
      }
    },
    {
      hostname = "stage-ed8-apiserver.eda-tw.com"
      service  = "http://ed8-apiserver.edatw-ed8.svc.cluster.local:80"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "stage-ed8-apiserver.eda-tw.com"
      }
    },
    {
      hostname = "salary-mailman.eda-tw.com"
      service  = "http://salary-mailman.edatw-salary-mailman.svc.cluster.local:8080"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "salary-mailman.eda-tw.com"
      }
    }
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "stage-ed8" = {
      name    = "stage-ed8"
      proxied = true
      comment = "Stage ED8 Application - EDATW"
    }
    "stage-ed8-apiserver" = {
      name    = "stage-ed8-apiserver"
      proxied = true
      comment = "Stage ED8 API Server - EDATW"
    }
    "salary-mailman" = {
      name    = "salary-mailman"
      proxied = true
      comment = "Salary Mailman Application - EDATW"
    }
  }
}

# Dedicated tunnel for OpenClaw (edatw-lab only). Kept separate from talos-edatw:
# that tunnel's connector also runs in other clusters that don't have OpenClaw, and
# a shared tunnel would let openclaw.eda-tw.com requests land on a connector with no
# OpenClaw backend (502). This tunnel's connector runs only in edatw-lab
# (argocd/edatw-openclaw).
module "openclaw_tunnel" {
  source = "../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "openclaw-edatw"

  ingress_rules = [
    {
      # OpenClaw agent UI. Gated by Cloudflare Access (access.tf); /assets is
      # bypassed there so the SPA's lazy-loaded chunks aren't redirected to login.
      hostname = "openclaw.eda-tw.com"
      service  = "http://openclaw.edatw-openclaw.svc.cluster.local:18789"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "openclaw.eda-tw.com"
      }
    }
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "openclaw" = {
      name    = "openclaw"
      proxied = true
      comment = "OpenClaw Agent UI - EDATW (dedicated tunnel, Cloudflare Access)"
    }
  }
}
