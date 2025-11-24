# Salary Mailman Application Infrastructure
# Deploys Cloudflare Tunnel and DNS for salary-mailman application

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Deploy salary-mailman Cloudflare Tunnel
module "edatw_tunnel" {
  source = "../../modules/cloudflared"

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
