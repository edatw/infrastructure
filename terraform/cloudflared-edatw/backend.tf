# Terraform Backend Configuration - Cloudflare R2 with SOPS
#
# This configuration stores Terraform state in Cloudflare R2 bucket with encryption.
# Backend credentials are encrypted with SOPS and automatically decrypted during init.
#
# Prerequisites:
# 1. Generate age encryption key: just sops-keygen
# 2. Create backend.hcl from backend.hcl.example with R2 credentials
# 3. Encrypt backend config: just tf-encrypt-backend && rm backend.hcl
# 4. Uncomment the backend block below
# 5. Initialize with SOPS: just tf-init (automatically decrypts backend.hcl.enc)
#
# See: README.md - "Secret Management with SOPS" section

# Uncomment after completing SOPS setup above
terraform {
  backend "s3" {}
}

# Workflow:
# 1. Generate age key (if not already done):
#    just sops-keygen
#
# 2. Create backend configuration:
#    cp backend.hcl.example backend.hcl
#    # Edit backend.hcl with your backend credentials
#
# 3. Encrypt backend config with SOPS:
#    just tf-encrypt-backend
#    rm backend.hcl  # Remove plaintext file
#
# 4. Uncomment the backend block above
#
# 5. Initialize Terraform (SOPS auto-decrypts):
#    just tf-init  # Automatically: sops exec-file backend.hcl.enc 'terraform init -backend-config={}'
#
# 6. Migrate state to remote backend:
#    Answer 'yes' when prompted to migrate state
#
# Daily Usage:
# - just tf-init   # SOPS decrypts backend.hcl.enc automatically
# - just tf-plan   # SOPS decrypts terraform.tfvars.enc automatically
# - just tf-apply  # SOPS decrypts terraform.tfvars.enc automatically
