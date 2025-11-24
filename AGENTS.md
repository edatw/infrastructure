# AGENTS.md - AI Assistant Guidance for EDA Infrastructure

This document provides guidance to AI assistants (Claude Code, GitHub Copilot, Cursor, etc.) when working with the EDA Taiwan infrastructure repository.
This is the **primary reference** designed to prevent vendor lock-in.

## Documentation Philosophy

**CRITICAL**: Avoid duplication between documentation files:

- **README.md**: Human-readable project overview, quick start, and common operations
- **AGENTS.md** (this file): AI-specific workflows, mandatory rules, and automation guidance
- **CLAUDE.md**: Claude Code-specific tool integration (references AGENTS.md)
- **STRUCTURE.md**: Repository structure, patterns, and migration guide

**Guideline**: When content is suitable for human users, place it in README.md and reference it from AGENTS.md. Do not duplicate.

## Repository Overview

**Purpose**: Infrastructure as Code for EDA Taiwan's Kubernetes applications and services

**Key Technologies**:

- **ArgoCD**: GitOps continuous delivery for Kubernetes applications
- **Kustomize**: Kubernetes native configuration management
- **SOPS/Age**: Secrets encryption and management
- **Terraform**: Infrastructure provisioning (Cloudflare, storage, networking)

**Current Structure**:

- `argocd/` - ArgoCD application manifests with SOPS-encrypted secrets
- `terraform/` - Terraform modules and environment configurations

See [STRUCTURE.md](STRUCTURE.md) for complete structure documentation and patterns.

## AI Assistant Principles

### Infrastructure as Code (IaC) Fundamentals

- **Declarative Configuration**: All infrastructure defined in version-controlled code
- **Immutable Infrastructure**: Prefer replacement over modification
- **Idempotency**: Operations can be safely repeated without side effects
- **Security by Default**: Secrets management, least privilege, encryption at rest/transit
- **GitOps Workflow**: Changes deployed through version-controlled pull requests

### AI Development Approach

- **Evidence-Based Decisions**: Reference documentation and existing patterns before suggesting changes
- **Documentation First**: Update docs/specs before implementation (Rule 1)
- **Structure Follows Standards**: Follow patterns defined in STRUCTURE.md
- **Security-First Mindset**: Never compromise on security fundamentals
- **Continuous Validation**: Use automated checks throughout development

## AI Assistant Mandatory Rules

**CRITICAL**: These rules must be followed for all infrastructure changes:

### Rule 1: Documentation Before Implementation

**Always update documentation BEFORE writing infrastructure code**:

1. **Review Existing**: Check `STRUCTURE.md` for patterns and `docs/` for current architecture
2. **Decision Documentation**: Create or update ADR in `docs/decisions/` explaining WHY (when applicable)
3. **Technical Specification**: Create or update spec in `specs/` defining WHAT and HOW (when applicable)
4. **Runbook Planning**: Plan operational procedures for `docs/runbooks/` (when applicable)
5. **Implementation**: Only then write ArgoCD/Terraform code
6. **README Update**: Update README.md if user-facing changes
7. **Validation**: Verify documentation matches implementation

**Example Workflow**:

```bash
# CORRECT: Documentation first, then code
1. Create docs/decisions/0001-add-monitoring-stack.md
2. Create specs/monitoring/prometheus-grafana.md
3. Write argocd/edatw-monitoring/ manifests
4. Create docs/runbooks/monitoring-operations.md

# WRONG: Code without documentation
1. Write argocd/edatw-monitoring/ manifests  # ❌ NO!
```

**Rationale**: Decisions and specs serve as blueprints, prevent rework, ensure knowledge transfer, and catch design issues before implementation.

### Rule 2: Temporary Scripts Location

**All temporary, experimental, or one-off scripts MUST be written to `/tmp`**:

- ✅ **Correct**: `/tmp/test-connection.sh`, `/tmp/debug-kustomize.sh`
- ❌ **Wrong**: `scripts/temp.sh`, `scripts/test.sh`

**scripts/ directory is ONLY for**:

- Production-ready automation scripts
- Version-controlled and maintained scripts
- Scripts that are part of the infrastructure workflow
- Scripts referenced in runbooks or documentation

**Rationale**: Keeps repository clean, prevents accidental commits of experimental code, clear separation between production and temporary code.

### Rule 3: Follow STRUCTURE.md Patterns

**All code must follow patterns defined in STRUCTURE.md**:

1. **Naming conventions**: Use `edatw-{service}` pattern for applications
2. **Directory structure**: Follow base/overlay pattern for ArgoCD apps
3. **File naming**: Use standard names (kustomization.yaml, ksops-generator.yaml, etc.)
4. **Secrets management**: Use SOPS with Age encryption
5. **Terraform structure**: Follow module and environment patterns

**Enforcement**: AI assistants should consult STRUCTURE.md before creating new code, verify naming conventions match patterns, and ensure directory structure follows standards.

### Rule 4: Documentation Update Validation

Before any PR or commit, verify:

1. **STRUCTURE.md consulted** for patterns and conventions
2. **ADR exists** for architectural decisions (when applicable)
3. **Spec is updated** with current configuration (when applicable)
4. **README updated** if new components added
5. **Runbook created/updated** for operational tasks (when applicable)
6. **Comments in code** reference documentation

**Enforcement**: AI assistants should prompt user to create documentation first, always consult STRUCTURE.md for patterns, and write temporary scripts to `/tmp`.

### Rule 5: Markdown Lint Compliance

**All Markdown files MUST pass markdown lint validation**:

- **Immediately after creating or editing** any `.md` file, run `markdownlint <file>` to verify compliance
- **Configuration**: Uses `.markdownlint.json` with relaxed line length (200 chars)
- **Common requirements**:
  - Headings must be surrounded by blank lines
  - Lists must be surrounded by blank lines
  - Consistent header styles and proper list formatting
  - No trailing spaces (unnecessary blank lines allowed per config)
- **Fix all lint errors** immediately after file changes

**Validation Command**:

```bash
# Validate single file
markdownlint STRUCTURE.md

# Validate all markdown files
markdownlint '**/*.md'
```

**Rationale**: Ensures consistent documentation quality, readability, and maintainability across the project.

## Key Workflows and Commands

### ArgoCD Application Workflows

**Creating New Application**:

```bash
# 1. Create directory structure following STRUCTURE.md pattern
mkdir -p argocd/edatw-myapp/{base,overlays/shangkuei-xyz-talos}

# 2. Create base manifests
# - namespace.yaml
# - serviceaccount.yaml
# - deployment.yaml (or statefulset.yaml, daemonset.yaml)
# - service.yaml
# - kustomization.yaml

# 3. Create overlay manifests
# - kustomization.yaml
# - ksops-generator.yaml
# - secret-myapp.sops.yaml (encrypted)

# 4. Validate Kustomize build
kustomize build argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# 5. Test dry-run
kubectl apply --dry-run=client -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos
```

**Updating Existing Application**:

```bash
# 1. Read existing configuration
cat argocd/edatw-myapp/base/deployment.yaml

# 2. Make changes following existing patterns

# 3. Validate Kustomize build
kustomize build argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# 4. Test changes
kubectl diff -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos
```

### Secrets Management with SOPS

**Creating New Secret**:

```bash
# 1. Create unencrypted secret file
cat > secret-myapp.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
  namespace: myapp
type: Opaque
stringData:
  password: "changeme"
  api-key: "secret"
EOF

# 2. Encrypt with SOPS
sops -e secret-myapp.yaml > secret-myapp.sops.yaml

# 3. Remove unencrypted file
rm secret-myapp.yaml

# 4. Add to ksops-generator.yaml
cat > ksops-generator.yaml <<EOF
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secret-generator
files:
  - secret-myapp.sops.yaml
EOF
```

**Editing Encrypted Secret**:

```bash
# Edit in place with SOPS
sops argocd/edatw-myapp/overlays/shangkuei-xyz-talos/secret-myapp.sops.yaml
```

### Terraform Workflows

**Working with Terraform Environments**:

```bash
# Navigate to environment
cd terraform/environments/cloudflared-edatw

# Initialize (decrypts configs automatically via Makefile)
make init

# Plan changes
make plan

# Apply changes
make apply

# Clean decrypted files
make clean
```

**Creating New Terraform Module**:

```bash
# 1. Create module directory
mkdir -p terraform/modules/mymodule

# 2. Create module files
touch terraform/modules/mymodule/{main.tf,variables.tf,outputs.tf,README.md}

# 3. Follow patterns from existing modules
# 4. Document module usage in README.md
# 5. Add example usage
```

### Validation Before Changes

**Always validate before suggesting infrastructure changes**:

```bash
# Kustomize validation
kustomize build argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Kubernetes dry-run
kubectl apply --dry-run=server -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Terraform format
terraform fmt -check -recursive terraform/

# Terraform validate
cd terraform/environments/myenv && terraform init && terraform validate

# Markdown lint
markdownlint '**/*.md'

# YAML lint
yamllint argocd/
```

## Repository Structure Reference

See [STRUCTURE.md](STRUCTURE.md) for complete documentation on:

- Directory structure and organization
- Naming conventions
- File patterns
- Secrets management
- ArgoCD application patterns
- Terraform module patterns
- Documentation templates
- Migration checklist
- Best practices

## Secrets Management

### SOPS Configuration

- **Location**: `argocd/.sops.yaml` for ArgoCD secrets
- **Encryption**: Uses Age keys from `~/.config/sops/age/keys.txt`
- **Pattern**: All secrets must be encrypted with `.sops.yaml` suffix

### Never Commit Unencrypted Secrets

**CRITICAL**: AI assistants must NEVER suggest committing:

- Unencrypted `.yaml` files containing secrets
- API keys, passwords, tokens in plain text
- Private keys or certificates
- Terraform `.tfvars` files without `.enc` suffix
- Backend configuration without `.enc` suffix

**Always**:

- Encrypt with SOPS before committing
- Use `.sops.yaml` suffix for encrypted files
- Use `.enc` suffix for encrypted Terraform configs
- Provide `.example` files for variable templates

## Git Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `chore`: Maintenance tasks

**Scopes**:

- `argocd`: ArgoCD application changes
- `terraform`: Terraform configuration changes
- `docs`: Documentation updates
- `ci`: CI/CD changes

**Examples**:

```bash
feat(argocd): add edatw-monitoring application

Add Prometheus and Grafana stack for cluster monitoring.
Includes SOPS-encrypted secrets for admin credentials.

Closes #42

---
fix(terraform): correct cloudflared tunnel configuration

Update tunnel credentials and routing rules for ed8 service.

---
docs(structure): update ArgoCD application patterns

Add multi-component application example and KSOPS workflow.
```

## Development Guidelines

### When Creating New ArgoCD Applications

1. **Consult STRUCTURE.md** for naming and directory patterns
2. **Use `edatw-{service}` naming** convention
3. **Create base/ and overlays/ structure** per STRUCTURE.md
4. **Encrypt all secrets with SOPS** before committing
5. **Validate Kustomize build** before committing
6. **Test with kubectl dry-run** to catch errors early
7. **Document application purpose** in argocd/README.md

### When Modifying Terraform

1. **Read existing code first** - Always use Read tool before Edit/Write
2. **Follow module patterns** defined in STRUCTURE.md
3. **Use Makefiles** for environment automation
4. **Encrypt sensitive variables** with SOPS
5. **Validate with terraform validate** before committing
6. **Test with terraform plan** to preview changes
7. **Document module usage** in README.md

### When Writing Documentation

1. **Check STRUCTURE.md** for documentation patterns
2. **Use ADR template** for architectural decisions
3. **Use Runbook template** for operational procedures
4. **Validate with markdownlint** immediately after changes
5. **Cross-reference related docs** with links
6. **Include practical examples** where applicable

## AI Workflow for Infrastructure Changes

### Phase 1: Understanding (Evidence Gathering)

1. **Read STRUCTURE.md** to understand patterns
2. **Review existing code** to understand current state
3. **Check documentation** for context and decisions
4. **Identify similar patterns** in existing applications
5. **Validate assumptions** with user if unclear

### Phase 2: Planning (Documentation First)

1. **Create or update ADR** if architectural decision needed
2. **Create or update spec** if new component/service
3. **Plan directory structure** following STRUCTURE.md
4. **Design secrets strategy** with SOPS encryption
5. **Document operational procedures** if needed

### Phase 3: Implementation (Code Second)

1. **Create directory structure** per STRUCTURE.md patterns
2. **Write base manifests** following existing patterns
3. **Create overlay configs** with encrypted secrets
4. **Write Terraform modules** following conventions
5. **Add automation** with Makefiles where appropriate

### Phase 4: Validation (Continuous Testing)

1. **Validate Kustomize** with `kustomize build`
2. **Test Kubernetes** with `kubectl apply --dry-run`
3. **Validate Terraform** with `terraform validate`
4. **Test Terraform** with `terraform plan`
5. **Lint markdown** with `markdownlint`
6. **Lint YAML** with `yamllint`

### Phase 5: Documentation (Update Everything)

1. **Update README.md** if new component added
2. **Update argocd/README.md** with application info
3. **Update terraform/README.md** with module usage
4. **Create runbook** for operational tasks
5. **Validate all docs** with markdownlint

## Security Considerations

### Secrets Management

- **Never commit unencrypted secrets** - Use SOPS encryption
- **Use Age keys** stored in `~/.config/sops/age/keys.txt`
- **Rotate keys regularly** - Document rotation procedures
- **Audit access** - Track who has access to secrets
- **Principle of least privilege** - Grant minimum necessary access

### Access Control

- **Kubernetes RBAC** - Define service accounts with minimal permissions
- **Terraform state** - Store in encrypted backend with access controls
- **Git repository** - Use branch protection and required reviews

### Network Security

- **Network policies** - Define ingress/egress rules
- **TLS encryption** - Use certificates for all services
- **Secure defaults** - Follow security best practices

## Testing Strategy

### Pre-Commit Testing

```bash
# Kustomize build test
kustomize build argocd/*/overlays/*/

# Kubernetes validation
kubectl apply --dry-run=server -k argocd/*/overlays/*/

# Terraform validation
terraform fmt -check -recursive terraform/
find terraform/environments -name "*.tf" -execdir terraform validate \;

# Documentation lint
markdownlint '**/*.md'

# YAML lint
yamllint argocd/ terraform/
```

### Integration Testing

- **Deploy to test cluster** - Validate changes in non-production
- **Smoke tests** - Verify basic functionality
- **Rollback testing** - Ensure changes can be reverted

## Common Pitfalls to Avoid

1. **Committing unencrypted secrets** - Always use SOPS
2. **Ignoring STRUCTURE.md patterns** - Follow established conventions
3. **Code before documentation** - Document first, then implement
4. **Skipping validation** - Always validate before committing
5. **Hardcoded values** - Use variables and ConfigMaps
6. **Missing namespaces** - Always define explicit namespaces
7. **No resource limits** - Define CPU/memory limits
8. **Unclear naming** - Follow `edatw-{service}` pattern

## Quick Reference Commands

```bash
# Kustomize
kustomize build argocd/edatw-app/overlays/cluster/
kubectl apply -k argocd/edatw-app/overlays/cluster/
kubectl diff -k argocd/edatw-app/overlays/cluster/

# SOPS
sops -e secret.yaml > secret.sops.yaml
sops secret.sops.yaml
sops -d secret.sops.yaml

# Terraform
cd terraform/environments/env-name
make init
make plan
make apply
make clean

# Validation
markdownlint '**/*.md'
yamllint argocd/
terraform fmt -check -recursive terraform/
kustomize build argocd/*/overlays/*/
```

## References

- **STRUCTURE.md**: Complete structure and patterns documentation
- **CLAUDE.md**: Claude Code-specific tool integration
- [Kustomize Documentation](https://kustomize.io/)
- [SOPS Documentation](https://github.com/mozilla/sops)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
