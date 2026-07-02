# Cloudflare edge rate limiting for the public OpenClaw endpoint.
#
# OpenClaw is exposed publicly via the cloudflared tunnel with NO Cloudflare
# Access (Access can't pass OpenClaw device pairing). Auth is OpenClaw's own
# gateway token + gateway-owned pairing. This rate-limit is edge defense-in-depth
# that does NOT interfere with pairing: it throttles per-source-IP request floods
# (e.g. token brute-force against the WS handshake) without any login challenge.
#
# 100 requests / 60s per client IP (per colo); offenders are blocked for 60s.
# Sized to sit well above a single user's SPA load + WebSocket reconnects while
# still stopping high-rate guessing. Raise requests_per_period if a legitimate
# multi-user NAT trips it.
resource "cloudflare_ruleset" "openclaw_ratelimit" {
  zone_id     = var.cloudflare_zone_id
  name        = "openclaw-ratelimit"
  description = "Per-IP rate limit for the public OpenClaw endpoint (defense-in-depth; Access removed)."
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    ref         = "openclaw_rl"
    description = "Block IPs exceeding 100 req/min to openclaw.eda-tw.com"
    expression  = "(http.host eq \"openclaw.eda-tw.com\")"
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 60
      requests_per_period = 100
      mitigation_timeout  = 60
    }
  }]
}
