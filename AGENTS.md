# AGENTS.md - AI Assistant Guidance for EDA Infrastructure

Behavioral rules for AI assistants working with this repository.
For project documentation, workflows, and commands, see [README.md](README.md).
For repository structure and patterns, see [STRUCTURE.md](STRUCTURE.md).

## Documentation Navigation

| Document | Purpose |
|----------|---------|
| **README.md** | Project overview, workflows, commands, operations |
| **AGENTS.md** (this file) | AI behavioral rules and workflow guidance |
| **CLAUDE.md** | Claude Code-specific tool integration |
| **STRUCTURE.md** | Repository structure, patterns, conventions |

Content suitable for human users belongs in README.md. This file contains only AI behavioral instructions.

## Principles

- **Evidence-Based**: Reference documentation and existing patterns before suggesting changes
- **Documentation First**: Update docs/specs before implementation (Rule 1)
- **Structure Follows Standards**: Follow patterns defined in STRUCTURE.md
- **Security-First**: Never compromise on security fundamentals
- **Continuous Validation**: Use automated checks throughout development

## Mandatory Rules

### Rule 1: Documentation Before Implementation

**Always update documentation BEFORE writing infrastructure code**:

1. **Review Existing**: Check `STRUCTURE.md` for patterns and `docs/` for current architecture
2. **Decision Documentation**: Create or update ADR in `docs/decisions/` explaining WHY (when applicable)
3. **Technical Specification**: Create or update spec in `specs/` defining WHAT and HOW (when applicable)
4. **Runbook Planning**: Plan operational procedures for `docs/runbooks/` (when applicable)
5. **Implementation**: Only then write ArgoCD/Terraform code
6. **README Update**: Update README.md if user-facing changes
7. **Validation**: Verify documentation matches implementation

### Rule 2: Temporary Scripts Location

**All temporary, experimental, or one-off scripts MUST be written to `/tmp`**.

`scripts/` directory is ONLY for production-ready, version-controlled scripts referenced in runbooks or documentation.

### Rule 3: Follow STRUCTURE.md Patterns

Consult STRUCTURE.md before creating new code. Verify naming conventions (`edatw-{service}`) and directory structure (base/overlay pattern) match established patterns.

### Rule 4: Documentation Update Validation

Before any PR or commit, verify:

1. STRUCTURE.md consulted for patterns and conventions
2. ADR exists for architectural decisions (when applicable)
3. README updated if new components added
4. Runbook created/updated for operational tasks (when applicable)

### Rule 5: Markdown Lint Compliance

Run `markdownlint <file>` immediately after creating or editing any `.md` file. Fix all lint errors before proceeding.

## AI Workflow for Infrastructure Changes

### Phase 1: Understanding

1. Read STRUCTURE.md to understand patterns
2. Review existing code for current state
3. Check documentation for context and decisions
4. Identify similar patterns in existing applications

### Phase 2: Planning

1. Create or update ADR if architectural decision needed
2. Create or update spec if new component/service
3. Plan directory structure following STRUCTURE.md

### Phase 3: Implementation

Follow development workflows in [README.md](README.md#development-workflow).

### Phase 4: Validation

Run applicable validation commands from [README.md](README.md#pre-commit-validation).

### Phase 5: Documentation

1. Update README.md if new component added
2. Update [argocd/README.md](argocd/README.md) with application info
3. Update [terraform/README.md](terraform/README.md) with module usage
4. Validate all docs with `markdownlint`

## Security Rules

- **Never commit unencrypted secrets** -- use SOPS with Age encryption
- **Never expose** API keys, passwords, tokens, private keys, or certificates in plain text
- **Always use `.sops.yaml` suffix** for encrypted secrets and `.enc` suffix for encrypted Terraform configs
- **Provide `.example` files** for variable templates

## Git Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>
```

**Types**: `feat`, `fix`, `docs`, `refactor`, `chore`
**Scopes**: `argocd`, `terraform`, `docs`, `ci`
