---
name: git-submodules
description: >
  Manage git submodules in the EDA infrastructure repository. Use this skill whenever
  the user mentions submodules, wants to update shared modules (makefiles, terraform-modules),
  needs to bump a dependency version, or encounters submodule-related git issues (detached HEAD,
  dirty submodules, init failures). Also trigger when the user asks about files inside
  `makefiles/` or `terraform/modules/` — these are read-only submodule paths that require
  cross-repo workflows. Trigger even for casual mentions like "update makefiles",
  "bump terraform modules", "submodule out of date", or "why is git showing dirty".
---

# Git Submodules — EDA Infrastructure

This repository uses two git submodules for shared, reusable code. Submodule directories
are **read-only within this repo** — their contents are maintained in separate upstream
repositories and pinned here at specific commits.

## Submodule Map

| Path | Upstream | Purpose |
|------|----------|---------|
| `makefiles/` | `shangkuei/makefiles.git` | Shared Makefile targets (init, plan, apply, clean) used by Terraform environments |
| `terraform/modules/` | `shangkuei/terraform-modules.git` | Reusable Terraform modules consumed by `terraform/environments/*/` |

## Critical Rule: Never Edit Submodule Files In-Place

Files inside `makefiles/` and `terraform/modules/` belong to their upstream repos. Editing
them directly in this repo creates "dirty submodule" state that:
- Pollutes `git status` and `git diff`
- Gets silently lost on the next `git submodule update`
- Causes confusing merge conflicts

If the user asks to modify something inside a submodule path, explain that the change must
be made in the upstream repo first, then the submodule pin updated here. Offer to help
plan the cross-repo workflow.

## Operations

### After Cloning

A fresh clone doesn't populate submodule directories. Initialize them:

```bash
git submodule update --init
```

If submodules show empty directories or missing files, this is almost always the fix.

### Check Submodule Status

```bash
git submodule status
```

Output interpretation:
- Clean: `<hash> makefiles (v1.2.3)` — pinned at that commit
- Dirty: `+<hash> makefiles (v1.2.3)` — local modifications exist (the `+` prefix)
- Not initialized: `-<hash> makefiles` — needs `git submodule update --init`
- Out of date: hash differs from what upstream `HEAD` points to (check with `--remote`)

### Update to Latest Upstream

Bump one submodule to the latest commit on its default branch:

```bash
# Fetch and checkout latest from upstream
git submodule update --remote makefiles

# Or for terraform modules
git submodule update --remote terraform/modules
```

This changes the pinned commit. The updated reference appears as a staged change
in `git diff --cached` — commit it to record the new pin.

### Update to a Specific Ref

When the user wants a specific commit, tag, or branch:

```bash
cd makefiles
git fetch
git checkout <ref>
cd ..
```

Then commit the new submodule reference from the parent repo.

### Add a New Submodule

```bash
git submodule add <url> <path>
```

This creates/updates `.gitmodules` and stages the submodule. Commit both.

### Remove a Submodule

This is a multi-step process — get confirmation before proceeding:

```bash
# 1. Remove from .gitmodules
git config -f .gitmodules --remove-section submodule.<path>

# 2. Remove from .git/config
git config --remove-section submodule.<path>

# 3. Remove the tracked directory
git rm --cached <path>
rm -rf <path>

# 4. Clean up .git/modules
rm -rf .git/modules/<path>
```

Commit the result. Always confirm with the user before executing removal steps —
they are destructive and affect the repo's history.

## Commit Messages

When committing submodule pin updates, use this format:

```
chore: bump <submodule-name> to <short-hash-or-tag>

Update <path> submodule to pick up <brief reason if known>.
```

Examples:
- `chore: bump makefiles to a1b2c3d`
- `chore: bump terraform-modules to v2.1.0`

## Troubleshooting

**"dirty" submodule in git status:**
Usually means uncommitted changes inside the submodule directory. If unintentional:
```bash
git submodule update --force makefiles
```
This discards local submodule changes — confirm with user first.

**Detached HEAD inside submodule:**
This is normal. Submodules always check out a specific commit, not a branch.
No action needed unless the user is trying to develop inside the submodule.

**Submodule not found after branch switch:**
If `.gitmodules` changed between branches:
```bash
git submodule sync
git submodule update --init
```

**Merge conflicts in submodule reference:**
The conflict is just two competing commit hashes. Resolve by choosing the correct
commit (usually the newer one), then:
```bash
cd <submodule-path>
git checkout <chosen-hash>
cd ..
git add <submodule-path>
```
