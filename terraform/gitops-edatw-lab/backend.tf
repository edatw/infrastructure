# EDATW Lab GitOps - Backend Configuration
#
# State is stored in Cloudflare R2 via the S3-compatible backend.
# Backend credentials are encrypted with SOPS (backend.hcl.enc).
#
# Setup:
#   1. cp backend.hcl.example backend.hcl
#   2. Fill in R2 credentials
#   3. just sops-encrypt-backend && rm backend.hcl
#   4. just terraform-init

terraform {
  backend "s3" {}
}
