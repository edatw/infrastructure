# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working with this repository.

## Primary Reference

See [AGENTS.md](AGENTS.md) for AI behavioral rules. See [README.md](README.md) for project documentation and workflows.

## File References

Use markdown link syntax for clickable references:

- Files: `[kustomization.yaml](argocd/edatw-cloudflared/base/kustomization.yaml)`
- Lines: `[deployment.yaml:42](argocd/edatw-ed8/base/statefulset.yaml#L42)`
- Ranges: `[README.md:10-25](STRUCTURE.md#L10-L25)`
- Directories: `[argocd/edatw-cloudflared/](argocd/edatw-cloudflared/)`

## Tool Usage Patterns

**Infrastructure Analysis**:

1. **Glob** for finding files: `argocd/**/*.yaml`, `terraform/**/*.tf`
2. **Grep** for searching patterns: `kind: Deployment`, `resource "`, `apiVersion:`
3. **Read** for examining configurations
4. **Task** (subagent_type=Explore) for open-ended codebase exploration

**Making Changes**:

1. **Always Read before Edit/Write** -- required for existing files
2. **TodoWrite** -- structure multi-step infrastructure changes
3. **Bash** -- validate with `kustomize build`, `terraform validate`
4. **Bash** -- test with `kubectl apply --dry-run`, `terraform plan`
