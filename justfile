# EDA Taiwan Infrastructure - Top-level Justfile
# Repo-wide tasks and environment delegation

set shell := ["bash", "-euo", "pipefail", "-c"]

# ============================================================================
# Configuration
# ============================================================================

# Terraform environments live flat under terraform/ (each a dir with its own
# justfile); terraform/modules is a submodule, not an environment.
tf_env_dir := "terraform"
cluster_env := "talos-cluster-edatw-lab"
argocd_dir := "argocd"

# ============================================================================
# Default & Help
# ============================================================================

[doc("Show available recipes")]
default:
    @just --list --unsorted

# ============================================================================
# Lint & Validate
# ============================================================================

[doc("Run all linters (pre-commit)")]
lint:
    pre-commit run --all-files

[doc("Lint markdown files")]
lint-md:
    markdownlint --config .markdownlint.json '**/*.md'

[doc("Lint YAML files")]
lint-yaml:
    yamllint -c .yamllint.yaml .

[doc("Check Terraform formatting")]
lint-tf:
    terraform fmt -check -recursive terraform/

[doc("Format Terraform files")]
fmt-tf:
    terraform fmt -recursive terraform/

[doc("Format all justfiles")]
fmt-just:
    #!/usr/bin/env bash
    set -euo pipefail
    just --fmt --unstable
    for f in $(find . -name justfile -not -path ./justfile); do
        just --fmt --unstable --justfile "$f"
    done
    echo "All justfiles formatted"

[doc("Check justfile formatting")]
check-just:
    #!/usr/bin/env bash
    set -euo pipefail
    just --fmt --check --unstable
    failed=0
    for f in $(find . -name justfile -not -path ./justfile); do
        if ! just --fmt --check --unstable --justfile "$f" 2>/dev/null; then
            echo "  [NEEDS FMT] $f"
            failed=1
        fi
    done
    [ "$failed" -eq 0 ] || { echo "Run 'just fmt-just' to fix"; exit 1; }

# ============================================================================
# ArgoCD Validation
# ============================================================================

[doc("Build and validate a kustomize overlay (app=<name> overlay=<name>)")]
kustomize-build app overlay:
    kustomize build {{ argocd_dir }}/{{ app }}/overlays/{{ overlay }}

[doc("Validate all kustomize overlays")]
kustomize-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for overlay in {{ argocd_dir }}/*/overlays/*/; do
        [ -f "$overlay/kustomization.yaml" ] || continue
        app=$(echo "$overlay" | cut -d/ -f2)
        env=$(echo "$overlay" | cut -d/ -f4)
        if kustomize build "$overlay" > /dev/null 2>&1; then
            echo "  [OK] $app/$env"
        else
            echo "  [FAIL] $app/$env"
            failed=$((failed + 1))
        fi
    done
    [ "$failed" -eq 0 ] && echo "All overlays valid" || { echo "$failed overlay(s) failed"; exit 1; }

# ============================================================================
# Terraform Environment Delegation
# ============================================================================

[doc("List available terraform environments")]
envs:
    #!/usr/bin/env bash
    set -euo pipefail
    # An env is a directory under terraform/ with its own justfile (excludes modules/).
    for d in {{ tf_env_dir }}/*/; do
        [ -f "${d}justfile" ] && basename "$d"
    done

[doc("Run a just recipe in a terraform environment (env=<name> recipe args)")]
tf env +recipe:
    just --justfile {{ tf_env_dir }}/{{ env }}/justfile {{ recipe }}

# ============================================================================
# Quick Shortcuts (talos-cluster-edatw-lab)
# ============================================================================

[doc("cluster: Initialize Terraform")]
cluster-init:
    just tf {{ cluster_env }} tf-init

[doc("cluster: Plan Terraform changes")]
cluster-plan:
    just tf {{ cluster_env }} tf-plan

[doc("cluster: Apply Terraform changes")]
cluster-apply:
    just tf {{ cluster_env }} tf-apply

[doc("cluster: Show Talos status (health + nodes + pods)")]
cluster-status:
    just tf {{ cluster_env }} talos-status

[arg('src', long='src')]
[doc("cluster: Merge generated kubeconfig into ~/.kube/config (flatten + back up)")]
cluster-kubeconfig src="terraform/talos-cluster-edatw-lab/generated/kubeconfig":
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{ src }}"
    dest="$HOME/.kube/config"
    if [ ! -f "$src" ]; then
        echo "Error: kubeconfig not found at $src" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        cp "$dest" "$dest.bak"
        echo "Backed up $dest -> $dest.bak"
        KUBECONFIG="$dest:$src" kubectl config view --flatten > "$dest.merged"
    else
        kubectl --kubeconfig "$src" config view --flatten > "$dest.merged"
    fi
    mv "$dest.merged" "$dest"
    chmod 600 "$dest"
    echo "Merged $src into $dest"
    kubectl config get-contexts

# ============================================================================
# Quick Shortcuts (gitops-edatw-lab)
# ============================================================================

[doc("gitops-edatw-lab: bump cert-manager/flux-operator/flux (latest, or pass versions) + update encrypted tfvars")]
gitops-bump *args:
    just tf gitops-edatw-lab bump-versions {{ args }}

# ============================================================================
# Git Helpers
# ============================================================================

[doc("Show repo status summary")]
status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Git"
    git status --short
    echo ""
    echo "==> Terraform Environments"
    for env in {{ tf_env_dir }}/*/; do
        [ -f "${env}justfile" ] || continue
        name=$(basename "$env")
        has_state=""
        [ -d "${env}.terraform" ] && has_state=" (initialized)"
        echo "  $name$has_state"
    done
    echo ""
    echo "==> ArgoCD Applications"
    for app in {{ argocd_dir }}/*/; do
        [ -d "$app" ] || continue
        name=$(basename "$app")
        overlays=$(ls -1 "$app/overlays/" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        echo "  $name -> $overlays"
    done
