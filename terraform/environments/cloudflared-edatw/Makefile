# ============================================================================
# Cloudflared EDATW Environment - Makefile
# ============================================================================
# Manages Cloudflared tunnel configuration with SOPS encryption
# Uses shared makefiles from https://github.com/shangkuei/makefiles
# ============================================================================

.PHONY: help

# Default target
.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration (required before including sops.mk)
# ============================================================================

# Domain identifier for this environment
SOPS_DOMAIN := terraform

# Environment name - determines key file location
# Key: ~/.config/sops/age/cloudflared-edatw.txt
SOPS_ENV_NAME := cloudflared-edatw

# Key location strategy: central (user home) or local (current directory)
SOPS_KEY_STRATEGY := central

# ============================================================================
# Terraform Configuration (optional, these are defaults)
# ============================================================================

# Encrypted files
TF_TFVARS_ENC := terraform.tfvars.enc
TF_BACKEND_ENC := backend.hcl.enc

# Auto-init before plan/apply (set to true for convenience)
TF_AUTO_INIT := false

# ============================================================================
# Include shared makefiles
# Order matters: sops.mk must be included before terraform.mk
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# ============================================================================
# Environment-specific targets
# ============================================================================

##@ Environment

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

workflow: ## Show SOPS setup workflow for this environment
	@echo ""
	@echo "$(_SOPS_BOLD)========================================$(_SOPS_NC)"
	@echo "$(_SOPS_BOLD)SOPS Encryption Setup Workflow$(_SOPS_NC)"
	@echo "$(_SOPS_BOLD)========================================$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Initial Setup:$(_SOPS_NC)"
	@echo "  1. make sops-keygen              # Generate age encryption key"
	@echo "  2. Update .sops.yaml with public key from: make sops-info"
	@echo ""
	@echo "$(_SOPS_YELLOW)Backend Configuration:$(_SOPS_NC)"
	@echo "  3. cp backend.hcl.example backend.hcl"
	@echo "  4. vim backend.hcl               # Add R2 credentials"
	@echo "  5. make tf-encrypt-backend       # Encrypt backend config"
	@echo "  6. rm backend.hcl                # Remove plaintext"
	@echo ""
	@echo "$(_SOPS_YELLOW)Variables Configuration:$(_SOPS_NC)"
	@echo "  7. cp terraform.tfvars.example terraform.tfvars"
	@echo "  8. vim terraform.tfvars          # Add secrets"
	@echo "  9. make tf-encrypt-tfvars        # Encrypt variables"
	@echo "  10. rm terraform.tfvars          # Remove plaintext"
	@echo ""
	@echo "$(_SOPS_YELLOW)Daily Usage:$(_SOPS_NC)"
	@echo "  make tf-init                     # Auto-decrypts backend.hcl.enc"
	@echo "  make tf-plan                     # Auto-decrypts terraform.tfvars.enc"
	@echo "  make tf-apply                    # Auto-decrypts terraform.tfvars.enc"
	@echo ""
	@echo "$(_SOPS_YELLOW)Edit Encrypted Files:$(_SOPS_NC)"
	@echo "  make tf-edit-tfvars              # Edit terraform.tfvars.enc in-place"
	@echo "  make tf-edit-backend             # Edit backend.hcl.enc in-place"

# ============================================================================
# Legacy target aliases (for backward compatibility)
# These map old target names to new shared makefile targets
# ============================================================================

##@ Legacy Aliases (backward compatibility)

.PHONY: init plan apply destroy validate format lint clean
.PHONY: age-keygen age-info encrypt-backend encrypt-tfvars

init: tf-init ## [Legacy] Initialize Terraform (use tf-init)
plan: tf-plan ## [Legacy] Generate plan (use tf-plan)
apply: tf-apply ## [Legacy] Apply changes (use tf-apply)
destroy: tf-destroy ## [Legacy] Destroy infrastructure (use tf-destroy)
validate: tf-validate ## [Legacy] Validate config (use tf-validate)
format: tf-fmt ## [Legacy] Format files (use tf-fmt)
lint: tf-lint ## [Legacy] Run linting (use tf-lint)
clean: tf-clean ## [Legacy] Clean local files (use tf-clean)

age-keygen: sops-keygen ## [Legacy] Generate key (use sops-keygen)
age-info: sops-info ## [Legacy] Show key info (use sops-info)
encrypt-backend: tf-encrypt-backend ## [Legacy] Encrypt backend (use tf-encrypt-backend)
encrypt-tfvars: tf-encrypt-tfvars ## [Legacy] Encrypt tfvars (use tf-encrypt-tfvars)
