# Cloudflare edge rate limiting for the public OpenClaw endpoint.
#
# OpenClaw is exposed publicly via the cloudflared tunnel with NO Cloudflare
# Access (Access can't pass OpenClaw device pairing). Auth is OpenClaw's own
# gateway token + gateway-owned pairing. This rate-limit is edge defense-in-depth
# that does NOT interfere with pairing: it throttles per-source-IP request floods
# (e.g. token brute-force against the WS handshake) without any login challenge.
#
# 50 ORIGIN-bound requests / 10s per client IP (per colo); offenders blocked 10s.
# period/mitigation_timeout are pinned to 10 because the zone's plan only permits
# a 10s window (free-tier rate limiting). requests_to_origin=true counts only
# cache-missing requests, so the SPA's (cacheable) static assets don't trip it —
# the WebSocket handshake + API (always origin) are what get throttled, which is
# exactly the brute-force surface. Raise requests_per_period if a NAT trips it.
resource "cloudflare_ruleset" "openclaw_ratelimit" {
  zone_id     = var.cloudflare_zone_id
  name        = "openclaw-ratelimit"
  description = "Per-IP rate limit for the public OpenClaw endpoint (defense-in-depth; Access removed)."
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    ref         = "openclaw_rl"
    description = "Block IPs exceeding 50 origin req/10s to openclaw.eda-tw.com"
    expression  = "(http.host eq \"openclaw.eda-tw.com\")"
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 50
      mitigation_timeout  = 10
      requests_to_origin  = true
    }
  }]
}
