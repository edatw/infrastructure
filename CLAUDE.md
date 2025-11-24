# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the EDA Taiwan infrastructure repository.

## Primary Reference

**IMPORTANT**: See [AGENTS.md](AGENTS.md) for the primary, vendor-neutral AI assistant guidance. This document only contains Claude Code-specific extensions.

## Claude Code-Specific Features

### File References

When referencing files or code locations in responses, use markdown link syntax for clickable references:

- Files: `[kustomization.yaml](argocd/edatw-cloudflared/base/kustomization.yaml)`
- Lines: `[deployment.yaml:42](argocd/edatw-ed8/base/statefulset.yaml#L42)`
- Ranges: `[README.md:10-25](STRUCTURE.md#L10-L25)`
- Directories: `[argocd/edatw-cloudflared/](argocd/edatw-cloudflared/)`

### Tool Usage Patterns

**Infrastructure Analysis**:

1. **Glob** for finding files: `argocd/**/*.yaml`, `terraform/**/*.tf`
2. **Grep** for searching patterns: `kind: Deployment`, `resource "`, `apiVersion:`
3. **Read** for examining configurations
4. **Task** (subagent_type=Explore) for open-ended codebase exploration

**Making Changes**:

1. **Always Read before Edit/Write** - Required for existing files
2. **TodoWrite** - Structure multi-step infrastructure changes
3. **Bash** - Validate with `kustomize build`, `terraform validate`
4. **Bash** - Test with `kubectl apply --dry-run`, `terraform plan`

### Task Management for Infrastructure

Use TodoWrite for complex infrastructure operations:

```text
1. Analysis: Review existing patterns in STRUCTURE.md
2. Documentation: Create/update ADR and specs
3. Implementation: Write ArgoCD/Terraform code
4. Validation: Kustomize build, kubectl dry-run, terraform validate
5. Testing: Deploy to test environment
6. Documentation: Update README and runbooks
```

### Workflow Integration

For validation commands, security scanning, and git commit conventions, see [AGENTS.md - Key Workflows and Commands](AGENTS.md#key-workflows-and-commands).

**Claude Code Specific**: Use TodoWrite tool to track multi-step validation workflows.

### Quick Reference

For complete documentation on:

- **Validation workflows**: See [AGENTS.md - Validation Before Changes](AGENTS.md#validation-before-changes)
- **ArgoCD workflows**: See [AGENTS.md - ArgoCD Application Workflows](AGENTS.md#argocd-application-workflows)
- **Secrets management**: See [AGENTS.md - Secrets Management with SOPS](AGENTS.md#secrets-management-with-sops)
- **Terraform workflows**: See [AGENTS.md - Terraform Workflows](AGENTS.md#terraform-workflows)
- **Git commit convention**: See [AGENTS.md - Git Commit Convention](AGENTS.md#git-commit-convention)
- **Repository structure**: See [STRUCTURE.md](STRUCTURE.md)
- **Development guidelines**: See [AGENTS.md - Development Guidelines](AGENTS.md#development-guidelines)
- **AI workflows**: See [AGENTS.md - AI Workflow for Infrastructure Changes](AGENTS.md#ai-workflow-for-infrastructure-changes)
- **Security considerations**: See [AGENTS.md - Security Considerations](AGENTS.md#security-considerations)

### Environment-Specific Guidance

| Environment | Location | Auto-Deploy | Approval | Use Case |
|-------------|----------|-------------|----------|----------|
| Development | `argocd/*/overlays/dev-*` | Yes (on merge) | No | Testing |
| Staging | `argocd/*/overlays/staging-*` | Manual trigger | Team lead | Pre-prod validation |
| Production | `argocd/*/overlays/*-talos` | Manual only | Multiple reviewers | Live workloads |

### Additional Context

- **Project overview**: [README.md](README.md)
- **Structure patterns**: [STRUCTURE.md](STRUCTURE.md)
- **ArgoCD applications**: [argocd/README.md](argocd/README.md)
- **Terraform guide**: [terraform/README.md](terraform/README.md)
