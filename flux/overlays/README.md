# Flux overlays — edatw-lab

Local, cluster-specific overlays that carry **SOPS-encrypted secrets** and small
edatw-lab deltas. Cluster-agnostic app bases are sourced remotely from
`shangkuei/infrastructure`; anything that holds a secret (or must differ per
cluster) lives here instead.

```text
flux/overlays/<app>/edatw-lab/
├── .gitignore               # never commit age keys / decrypted material
├── .sops.yaml               # which age key encrypts *.enc.yaml here
├── justfile                 # imports the shared SOPS recipes + app secret recipe
├── kustomization.yaml       # resources for this overlay
└── <something>.enc.yaml      # SOPS-encrypted Secret(s), naming: *.enc.yaml
```

A Flux `Kustomization` in [`../clusters/edatw-lab/`](../clusters/edatw-lab/)
points its `spec.path` at the overlay and decrypts with `decryption.provider: sops`.

## The shared secret model

All edatw-lab overlays encrypt to **one** age key (the cluster's Flux key), so a
single `sops-age` Secret in `flux-system` decrypts everything:

| | |
|---|---|
| `sops_env_name` | `flux-edatw-lab` |
| Private key (central) | `~/.config/sops/age/flux-edatw-lab.txt` |
| Public key (in every `.sops.yaml`) | `age142yu9a74xm8vfls25jvmdvw0c3yrcsvdht0ah9yu8cysya2qqyaqmg6y0a` |

The key already exists — **scaffolding a new overlay reuses it, it does not
generate a new one.** (The key itself is owned/bootstrapped by
[`flux-instance/edatw-lab`](flux-instance/edatw-lab/); see its README/justfile.)

## Creating the common resources for a new overlay

From repo root, `app=<name>`:

```bash
mkdir -p flux/overlays/$app/edatw-lab && cd flux/overlays/$app/edatw-lab
```

### 1. `.gitignore` — identical in every overlay

```gitignore
# SOPS private keys - NEVER commit these
age-key.txt
age-key.txt.pub

# Decrypted secrets - NEVER commit these
*.decrypted

# Temporary files
*.tmp
*.bak
```

### 2. `.sops.yaml` — same key, only the comment changes

```yaml
# SOPS configuration for <app> secrets
# Uses the edatw-lab Flux age key (same key as the other flux overlays).
# Naming convention: *.enc.yaml (encrypted files)

creation_rules:
  - path_regex: \.enc\.yaml$
    encrypted_regex: '^(data|stringData)$'
    age: age142yu9a74xm8vfls25jvmdvw0c3yrcsvdht0ah9yu8cysya2qqyaqmg6y0a
```

### 3. `justfile` — basic form (no secret) vs. with a secret recipe

The justfile always sets `sops_env_name` and imports the shared module from
`makefiles/sops.just` (four levels up). That import alone provides
`sops-encrypt`, `sops-decrypt`, `sops-edit`, `sops-validate`, `sops-init-config`,
etc. (run `just --list`).

**Basic** (overlay has no secret of its own):

```just
# <app> overlay - edatw-lab

set shell := ["bash", "-euo", "pipefail", "-c"]

# Shared makefiles SOPS module: provides the Flux age key path (sops_age_key_file)
# and generic sops-* recipes. Reuses the edatw-lab Flux age key.
sops_env_name := "flux-edatw-lab"

import '../../../../makefiles/sops.just'

[doc("List recipes")]
default:
    @just --list --unsorted
```

**With a secret recipe** — add a recipe that *gets* the secret values and
*encrypts* them in place with the shared key. The pattern: write a plaintext
`Secret` to `<name>.enc.yaml`, then `sops --encrypt --in-place` using
`sops_age_key_file` (provided by the import). Example, prompting for the values:

```just
secret_enc := "secret-<name>.enc.yaml"

[doc("Generate + encrypt the <ns>/<name> secret (prompts)")]
secret-<name>:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "{{ sops_age_key_file }}" ] || { echo "Missing {{ sops_age_key_file }}"; exit 1; }
    read -rp "value: " val
    {
      echo "---"; echo "apiVersion: v1"; echo "kind: Secret"
      echo "metadata:"; echo "  name: <name>"; echo "  namespace: <ns>"
      echo "type: Opaque"; echo "stringData:"
      echo "  key: ${val}"
    } > "{{ secret_enc }}"
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops --encrypt --in-place "{{ secret_enc }}"
```

> Don't have the central key yet on this machine? `just sops-init-config`
> generates it (if missing) and fills the `.sops.yaml` placeholder. To pull an
> existing key from your password manager: `just sops-import-key --age_key_file <path>`.

### 4. `kustomization.yaml` — wire the resources

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # - secret-<name>.enc.yaml   # uncomment AFTER `just secret-<name>` encrypts it

labels:
  - pairs:
      app.kubernetes.io/instance: edatw-lab
      app.kubernetes.io/environment: production
```

## Activation order (avoid a broken build)

The encrypted file must exist before it is referenced, or both `kustomize build`
and Flux SOPS decryption fail:

1. `just secret-<name>` → writes and encrypts `secret-<name>.enc.yaml`.
2. Uncomment the resource in this overlay's `kustomization.yaml`.
3. Uncomment the overlay's Flux `Kustomization` in
   [`../clusters/edatw-lab/`](../clusters/edatw-lab/).
4. `just sops-validate` to confirm every `*.enc.yaml` round-trips.

## Reference overlays

- [`openshell/edatw-lab`](openshell/edatw-lab/) — overlay carrying a SOPS-encrypted secret.
- [`flux-instance/edatw-lab`](flux-instance/edatw-lab/) — owns the shared age key.
- [`kagent/edatw-lab`](kagent/edatw-lab/) — basic justfile, common files only.
