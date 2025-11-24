# Infrastructure Repository Structure and Patterns

This document defines the structure and patterns for the EDA infrastructure repository, based on the reference repository at `/Users/shangkuei/dev/shangkuei/infrastructure`.

## Current Repository Structure

```text
infrastructure/
├── argocd/              # ✅ ArgoCD application manifests
│   ├── .sops.yaml       # ✅ SOPS configuration for secrets
│   ├── edatw-cloudflared/
│   ├── edatw-ed8/
│   └── edatw-salary-mailman/
│
└── terraform/           # ✅ Terraform configurations
    ├── environments/    # ✅ Environment-specific configs
    └── modules/         # ✅ Reusable Terraform modules
```

## Target Repository Structure

Based on the reference repository, the complete structure should be:

```text
infrastructure/
├── .github/              # TODO: GitHub Actions workflows
│   └── workflows/        # CI/CD pipelines
│       ├── ansible-lint.yml
│       └── terraform-plan.yml
│
├── argocd/              # ✅ EXISTING: ArgoCD application manifests
│   ├── .sops.yaml       # ✅ EXISTING: SOPS configuration
│   ├── {app-name}/      # Application directories (edatw-* pattern)
│   │   ├── base/        # Base Kustomize configuration
│   │   │   ├── deployment.yaml (or statefulset/daemonset)
│   │   │   ├── service.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/    # Environment-specific overlays
│   │       └── {cluster-name}/
│   │           ├── kustomization.yaml
│   │           ├── ksops-generator.yaml
│   │           └── secret-*.sops.yaml
│   └── README.md        # TODO: ArgoCD documentation
│
├── terraform/           # ✅ EXISTING: Terraform configurations
│   ├── modules/        # ✅ EXISTING: Reusable modules
│   │   └── {module-name}/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   ├── environments/   # ✅ EXISTING: Environment configs
│   │   ├── {env-name}/
│   │   │   ├── .sops.yaml
│   │   │   ├── backend.tf
│   │   │   ├── backend.hcl.enc
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── terraform.tfvars.enc
│   │   │   ├── terraform.tfvars.example
│   │   │   ├── Makefile
│   │   │   └── README.md
│   │   └── README.md
│   └── README.md       # TODO: Terraform documentation
│
├── docs/               # TODO: Documentation
│   ├── architecture/   # Architecture diagrams and docs
│   │   └── README.md
│   ├── decisions/      # Architectural Decision Records (ADRs)
│   │   └── README.md
│   ├── guides/         # How-to guides and tutorials
│   │   └── README.md
│   ├── runbooks/       # Operational procedures
│   │   └── README.md
│   └── README.md       # Documentation index
│
├── specs/              # TODO: Technical specifications
│   └── README.md       # Specifications index
│
├── .gitignore         # TODO: Git ignore patterns
├── .markdownlint.json # TODO: Markdown linting config
├── .pre-commit-config.yaml # TODO: Pre-commit hooks
├── .tflint.hcl        # TODO: Terraform linting config
├── .yamllint.yaml     # TODO: YAML linting config
├── AGENTS.md          # TODO: AI assistant guidance
├── CLAUDE.md          # TODO: Claude Code-specific guidance
├── README.md          # TODO: Project overview
├── STRUCTURE.md       # ✅ This file
└── TODO.md            # TODO: Project tasks
```

## Naming Conventions

### Application Directories

Pattern: `{organization-prefix}-{service-name}`

**Current Examples**:

- `edatw-cloudflared` - Cloudflare tunnel for EDA Taiwan
- `edatw-ed8` - ED8 database service
- `edatw-salary-mailman` - Salary mailman service

**Benefits**:

- Clear organization ownership
- Namespace collision prevention
- Easy filtering and searching
- Consistent naming across environments

### Cluster and Environment Names

Pattern: `{domain-name}-{platform}`

**Examples**:

- `shangkuei-xyz-talos` - Talos cluster for shangkuei.xyz domain
- `edatw-prod-talos` - Production Talos cluster for EDA Taiwan
- `edatw-dev-k3s` - Development K3s cluster

### File Naming Patterns

**Kustomize Base**:

- `namespace.yaml` - Namespace definition
- `serviceaccount.yaml` - Service account
- `deployment.yaml` or `statefulset.yaml` or `daemonset.yaml` - Workload
- `service.yaml` - Service definition
- `kustomization.yaml` - Kustomize manifest

**Kustomize Overlays**:

- `kustomization.yaml` - Overlay manifest
- `ksops-generator.yaml` - KSOPS generator configuration
- `secret-{name}.sops.yaml` - Encrypted secrets
- `persistent-volume-{name}.yaml` - Storage resources
- `storage-class-{name}.yaml` - Storage class definitions

**Terraform**:

- `main.tf` - Main configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `backend.tf` - Backend configuration
- `terraform.tfvars.enc` - Encrypted variables
- `terraform.tfvars.example` - Example variables (unencrypted)
- `backend.hcl.enc` - Encrypted backend config

## Secrets Management

### SOPS Configuration

**Per-Environment Pattern**: Each environment has its own `.sops.yaml` for security isolation.

**Current Locations**:

- `argocd/.sops.yaml` - ✅ For ArgoCD application secrets

**Recommended Locations**:

- `terraform/environments/{env}/.sops.yaml` - For Terraform variables

**Example `.sops.yaml`**:

```yaml
creation_rules:
  - path_regex: \.sops\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Age Key Management

**Storage Location**: `~/.config/sops/age/keys.txt`

**Key Types**:

- **ArgoCD Age Key**: Used by ArgoCD KSOPS plugin for application secrets
- **Terraform Age Key**: Used for Terraform variable encryption

**Encryption Workflow**:

```bash
# Encrypt secret
sops -e secret.yaml > secret.sops.yaml

# Decrypt secret (for editing)
sops secret.sops.yaml

# Encrypt Terraform variables
sops -e terraform.tfvars > terraform.tfvars.enc

# Decrypt backend config
sops -d backend.hcl.enc > backend.hcl
```

## ArgoCD Application Patterns

### Base Configuration Structure

```yaml
# base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-namespace

---
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - deployment.yaml
  - service.yaml
```

### Overlay Configuration Structure

```yaml
# overlays/{cluster}/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: app-namespace

bases:
  - ../../base

generators:
  - ksops-generator.yaml

resources:
  - persistent-volume.yaml

patchesStrategicMerge:
  - deployment-patches.yaml
```

### KSOPS Generator Pattern

```yaml
# overlays/{cluster}/ksops-generator.yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secret-generator
files:
  - secret-app.sops.yaml
```

### Multi-Component Applications

For applications with multiple services (database, backend, frontend):

```text
edatw-ed8/
├── base/
│   ├── configs/          # ConfigMaps
│   ├── scripts/          # Startup scripts
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── statefulset.yaml
│   ├── service.yaml
│   ├── persistent-volume-claim-*.yaml
│   ├── cronjob-*.yaml
│   └── kustomization.yaml
└── overlays/
    └── shangkuei-xyz-talos/
        ├── persistent-volume-*.yaml
        ├── storage-class-*.yaml
        ├── secret-*.sops.yaml
        ├── ksops-generator.yaml
        └── kustomization.yaml
```

## Terraform Module Patterns

### Module Structure

```text
terraform/modules/{module-name}/
├── main.tf          # Primary resource definitions
├── variables.tf     # Input variables with descriptions
├── outputs.tf       # Output values
├── versions.tf      # Provider version constraints (optional)
└── README.md        # Module documentation
```

### Environment Structure

```text
terraform/environments/{env-name}/
├── .sops.yaml                    # SOPS configuration
├── backend.tf                    # Backend configuration
├── backend.hcl.enc               # Encrypted backend config
├── main.tf                       # Environment configuration
├── variables.tf                  # Variable definitions
├── outputs.tf                    # Output values
├── terraform.tfvars.enc          # Encrypted variables
├── terraform.tfvars.example      # Example variables
├── Makefile                      # Automation commands
└── README.md                     # Environment documentation
```

### Makefile Pattern

```makefile
.PHONY: init plan apply destroy clean

init:
	@echo "Decrypting backend configuration..."
	@sops -d backend.hcl.enc > backend.hcl
	@echo "Decrypting terraform.tfvars..."
	@sops -d terraform.tfvars.enc > terraform.tfvars
	@echo "Initializing Terraform..."
	@terraform init -backend-config=backend.hcl

plan: init
	@terraform plan

apply: init
	@terraform apply

destroy: init
	@terraform destroy

clean:
	@rm -f backend.hcl terraform.tfvars
	@rm -rf .terraform
```

## Documentation Patterns

### Architectural Decision Records (ADRs)

**Location**: `docs/decisions/`

**Format**: `{NNNN}-{title}.md`

**Template**:

```markdown
# ADR-{NNNN}: {Title}

## Status

{Proposed | Accepted | Deprecated | Superseded}

## Context

{What is the issue we're addressing?}

## Decision

{What is the change that we're proposing?}

## Consequences

{What becomes easier or more difficult?}

## Alternatives Considered

{What other options did we evaluate?}

## References

- [Related ADR]()
- [External documentation]()
```

### Runbooks

**Location**: `docs/runbooks/`

**Format**: `{NNNN}-{operation}.md`

**Template**:

```markdown
# Runbook: {Operation Name}

## Purpose

{What this runbook helps you accomplish}

## Prerequisites

- Tool requirements
- Access requirements
- Knowledge requirements

## Steps

### 1. {Step Name}

{Detailed instructions}

### 2. {Next Step}

{More instructions}

## Troubleshooting

### Issue: {Common Problem}

**Symptoms**: {How to recognize}
**Solution**: {How to fix}

## Rollback

{How to undo changes if needed}

## References

- [Related documentation]()
```

## Migration Checklist

### Phase 1: Foundation (Configuration Files)

- [ ] Copy `.gitignore` from reference repository
- [ ] Add `.markdownlint.json` configuration
- [ ] Add `.pre-commit-config.yaml` configuration
- [ ] Add `.tflint.hcl` configuration
- [ ] Add `.yamllint.yaml` configuration

### Phase 2: Documentation Structure

- [ ] Create `docs/` directory
- [ ] Create `docs/decisions/` with README.md
- [ ] Create `docs/architecture/` with README.md
- [ ] Create `docs/guides/` with README.md
- [ ] Create `docs/runbooks/` with README.md
- [ ] Create `specs/` with README.md
- [ ] Create `AGENTS.md` for AI assistant guidance
- [ ] Create `CLAUDE.md` for Claude Code integration
- [ ] Create comprehensive `README.md`
- [ ] Create `TODO.md` for project tracking

### Phase 3: ArgoCD Documentation

- [ ] Create `argocd/README.md` documentation
- [ ] Document each application's purpose
- [ ] Document KSOPS setup and usage
- [ ] Create migration guides if needed

### Phase 4: Terraform Documentation

- [ ] Create `terraform/README.md` documentation
- [ ] Create `terraform/environments/README.md`
- [ ] Add README.md to each module
- [ ] Add README.md to each environment
- [ ] Document module usage and examples

### Phase 5: CI/CD Setup

- [ ] Create `.github/workflows/` directory
- [ ] Add Terraform plan workflow
- [ ] Add Terraform format check workflow
- [ ] Add markdown lint workflow
- [ ] Add YAML lint workflow

### Phase 6: Best Practices Documentation

- [ ] Document secrets management workflow
- [ ] Document deployment procedures
- [ ] Document troubleshooting guides
- [ ] Document rollback procedures

## Best Practices

### File Organization

1. **Keep related files together**: Group by application or module
2. **Use consistent naming**: Follow established patterns
3. **Separate base from overlays**: Use Kustomize inheritance
4. **One resource per file**: For clarity and maintainability (when practical)
5. **Document in place**: README in each major directory

### Security

1. **Never commit unencrypted secrets**: Use SOPS for all sensitive data
2. **Use per-environment keys**: Isolate secrets between environments
3. **Rotate keys regularly**: Document key rotation procedures
4. **Audit access**: Track who has access to which secrets
5. **Follow principle of least privilege**: Grant minimum necessary permissions

### Documentation

1. **Documentation before code**: Create ADRs before implementation (where applicable)
2. **Keep docs updated**: Update with code changes
3. **Link related docs**: Cross-reference ADRs, specs, runbooks
4. **Include examples**: Show real-world usage
5. **Validate markdown**: Run markdownlint on all docs

### Version Control

1. **Atomic commits**: One logical change per commit
2. **Descriptive messages**: Follow conventional commits
3. **Review before merge**: Require PR approval (when applicable)
4. **Test before commit**: Use pre-commit hooks
5. **Tag releases**: Version important milestones

## Quick Commands

### ArgoCD Operations

```bash
# View application structure
tree argocd/edatw-cloudflared

# Validate Kustomize
kustomize build argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos

# Edit encrypted secret
sops argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos/secret-cloudflared.yaml
```

### Terraform Operations

```bash
# Initialize environment
cd terraform/environments/cloudflared-edatw
make init

# Plan changes
make plan

# Apply changes
make apply

# Clean decrypted files
make clean
```

### Documentation Validation

```bash
# Lint all markdown files
markdownlint '**/*.md'

# Lint specific file
markdownlint STRUCTURE.md

# Lint YAML files
yamllint argocd/

# Lint Terraform
terraform fmt -check -recursive terraform/
```

## References

- **Reference Repository**: `/Users/shangkuei/dev/shangkuei/infrastructure`
- [Kustomize Documentation](https://kustomize.io/)
- [SOPS Documentation](https://github.com/mozilla/sops)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
