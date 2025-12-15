# ============================================================================
# edatw-salary-mailman overlay for edatw-cluster - SOPS Management
# ============================================================================

.PHONY: help encrypt-all list validate rekey-all
.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := argocd
SOPS_ENV_NAME := argocd-edatw-ksops
SOPS_KEY_STRATEGY := central

# SOPS config location (relative to this directory)
SOPS_CONFIG := ../../../.sops.yaml

# Files to manage
SOPS_FILES := $(wildcard secret-*.yaml)

# ============================================================================
# Include shared makefile
# ============================================================================

include ../../../../makefiles/sops.mk

# ============================================================================
# Overlay targets
# ============================================================================

##@ Overlay Operations

help: ## Display this help
	@echo ""
	@echo "edatw-salary-mailman / edatw-cluster"
	@echo "Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

list: ## List files and encryption status
	@echo "$(_SOPS_BLUE)==> Files in this overlay:$(_SOPS_NC)"
	@for f in $(SOPS_FILES); do \
		if [ -f "$$f" ]; then \
			if grep -q "^sops:" "$$f" 2>/dev/null; then \
				echo "  $(_SOPS_GREEN)[encrypted]$(_SOPS_NC) $$f"; \
			else \
				echo "  $(_SOPS_YELLOW)[plaintext]$(_SOPS_NC) $$f"; \
			fi; \
		fi; \
	done

encrypt-all: ## Encrypt all unencrypted files
	@for f in $(SOPS_FILES); do \
		if [ -f "$$f" ] && ! grep -q "^sops:" "$$f" 2>/dev/null; then \
			$(MAKE) -s sops-encrypt FILE="$$f"; \
		fi; \
	done

validate: ## Validate all encrypted files
	@for f in $(SOPS_FILES); do \
		if [ -f "$$f" ] && grep -q "^sops:" "$$f" 2>/dev/null; then \
			if SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d "$$f" >/dev/null 2>&1; then \
				echo "  $(_SOPS_GREEN)✓$(_SOPS_NC) $$f"; \
			else \
				echo "  $(_SOPS_RED)✗$(_SOPS_NC) $$f"; \
			fi; \
		fi; \
	done

rekey-all: ## Re-encrypt all files with current config
	@for f in $(SOPS_FILES); do \
		if [ -f "$$f" ] && grep -q "^sops:" "$$f" 2>/dev/null; then \
			$(MAKE) -s sops-rekey FILE="$$f"; \
		fi; \
	done
