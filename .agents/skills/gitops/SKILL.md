---
name: gitops
description: Configure the `gitops` Terraform module (cert-manager + Flux Operator + FluxInstance with SOPS). Use when the user is bootstrapping Flux on a Kubernetes cluster, configuring the FluxInstance, wiring SOPS-encrypted secrets into Flux, or tuning cert-manager's DNS01 setup.
---

# gitops module

Bootstraps Flux CD on a Kubernetes cluster via the Flux Operator (Helm), plus cert-manager (Helm) for webhook certificates and a `sops-age` Secret for decrypting manifests.

Source repo: `github.com/shangkuei/terraform-modules//gitops`. Pin via `?ref=<tag>`.

## Canonical block

```hcl
module "gitops" {
  source = "git::https://github.com/shangkuei/terraform-modules.git//gitops?ref=v1.0.0"

  cluster_name = "my-cluster"
  cluster_path = "./kubernetes/clusters/my-cluster"

  github_owner      = "my-org"
  github_repository = "infrastructure"
  github_token      = var.github_token
  github_branch     = "main"

  sops_age_key = file("~/.config/sops/age/my-cluster-flux.txt")
}
```

The calling module must configure `kubernetes`, `helm`, and `kubectl` providers — the module does not declare them.

## Required inputs

- `cluster_name` — display name; surfaces in outputs.
- `cluster_path` — path inside the Git repo where the cluster's manifests live (Flux Kustomization root).
- `github_owner`, `github_repository` — Flux uses this to construct the Git source.
- `github_token` — PAT with repo read (write if using image automation). Stored as a Kubernetes Secret `flux-system/flux-git-credentials`.
- `sops_age_key` — full age private key content (read from file). Stored as Secret `flux-system/sops-age`. Do **not** pass the public key.

## Common optional inputs

- `github_branch` (default `"main"`) — tracked branch.
- `flux_namespace` (default `"flux-system"`).
- `flux_components_extra` (default `[]`) — e.g., `["image-reflector-controller", "image-automation-controller"]`.
- `cert_manager_version` (default `"v1.19.1"`), `flux_operator_version` (default `"0.33.0"`), `flux_version` (default `"v2.7.3"`).
- `cert_manager_dns01_recursive_nameservers` (default `["1.1.1.1:53", "8.8.8.8:53"]`) — DNS resolvers for the DNS01 self-check.
- `cert_manager_enable_gateway_api` (default `true`) — requires cert-manager v1.15+.

## Key outputs

- `flux_namespace`, `cert_manager_namespace` — where each is installed.
- `git_repository`, `git_branch`, `cluster_path` — echo of inputs for downstream resources to reference.
- `component_versions` — installed versions; useful for upgrade audit.
- `verification_commands`, `flux_logs_commands` — printable diagnostic command snippets.

## Gotchas

- **`sops_age_key` is the private key.** It's the entire armored content (typically `AGE-SECRET-KEY-...`),
  not a path or pubkey. Mis-passing it surfaces as a working Flux that silently can't decrypt — the
  FluxInstance reconciles but Kustomizations stall with SOPS errors. Verify with
  `kubectl -n flux-system get secret sops-age`.
- **Provider configuration is the caller's job.** This module declares the providers as requirements but
  does *not* configure them — typically you wire them with outputs from a `talos_cluster` (or equivalent)
  module. Misconfigured providers manifest as `terraform plan` failures, not module errors.
- **Helm/Kubernetes ordering matters across `terraform apply`.** The first apply against a fresh cluster
  will create cert-manager → flux-operator → FluxInstance in dependency order. If the apply is interrupted
  between cert-manager and flux-operator install, the next plan may report churn; re-apply.
- **`flux_components_extra` is additive** to the default set. Don't list `source-controller`,
  `kustomize-controller`, `helm-controller`, or `notification-controller` here — they're already on.
  Only add the optional ones (image-reflector/image-automation).
- **`cluster_path` is repo-relative** (e.g., `clusters/prod`), not absolute. Flux fails reconcile silently
  with a misformed path; check `kubectl -n flux-system get kustomizations -o yaml`.
- **Switching `cert_manager_version` triggers CRD churn.** Major cert-manager upgrades may require a
  manual `kubectl apply -f <crds>` before Helm can roll forward — read cert-manager's release notes first.
