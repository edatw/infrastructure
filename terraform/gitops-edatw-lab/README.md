# EDATW Lab GitOps

Terraform environment that bootstraps **Flux CD** on the
[talos-cluster-edatw-lab](../talos-cluster-edatw-lab/) cluster using the
[`gitops`](../modules/gitops/) module (cert-manager + Flux Operator +
FluxInstance with SOPS decryption).

This is a **separate root module** from the cluster on purpose: its
`kubernetes` / `helm` / `kubectl` providers need a **live** cluster, while the
cluster root only *generates* machine configs.

## How it connects to the cluster

Providers are configured from **explicit credentials** supplied via encrypted
`terraform.tfvars`:

- `kubernetes_host` — API endpoint (e.g. `https://100.64.0.10:6443`)
- `kubernetes_token` — a short-lived `gitops-admin` ServiceAccount token
- `kubernetes_cluster_ca_certificate` — base64 cluster CA

No remote state, no kubeconfig file, no Talos data source.

The token is bound-duration (default `1h`). Don't hand-edit it: run
`just tf-refresh-token` to mint a fresh token and rewrite it into the encrypted
tfvars, then run terraform — e.g. `just tf-refresh-token tf-apply`. Override the
ServiceAccount or TTL with `GITOPS_SA` / `GITOPS_TOKEN_TTL`.

## Two age keys (don't conflate them)

| Key | Purpose | Where |
|-----|---------|-------|
| `talos-cluster-edatw-lab.txt` | Encrypts **this env's** `terraform.tfvars` / `backend.hcl` (reused from the cluster env). | `.sops.yaml`, `just sops-*` |
| `edatw-lab-flux.txt` | **Dedicated** Flux key — its private content becomes the in-cluster `flux-system/sops-age` secret for decrypting repo manifests. | `var.sops_age_key_path` |

The Flux key is the **private** key (`AGE-SECRET-KEY-...`). Its **public** key
goes in the repo's manifest `.sops.yaml` so committed secrets encrypt to Flux.

## Flux manifest path

Flux syncs `github.com/edatw/infrastructure` and reconciles the Kustomization
root at **`flux/clusters/edatw-lab`** (`var.cluster_path`). That directory does not exist
yet — create it with your Flux `Kustomization`/`HelmRelease` manifests. Until it
exists, the FluxInstance reconciles but the cluster Kustomization reports a
missing path (expected). The repo currently uses `argocd/`; this is the first
Flux tree.

## Prerequisites

- The cluster is bootstrapped, healthy, and reachable.
- Terraform >= 1.6.0, [just](https://just.systems/), [SOPS](https://github.com/getsops/sops) + [age](https://age-encryption.org/).
- A GitHub PAT with repo read (write only for image automation).
- A `gitops-admin` ServiceAccount token + cluster CA (create the SA first; see
  Quick Start step 0 and `terraform.tfvars.example`).

## Quick Start

```bash
# 0. Create the gitops-admin ServiceAccount + cluster-admin binding (one-time).
#    Its short-lived token is minted per-run by `just tf-refresh-token` (step 4).
kubectl -n kube-system create serviceaccount gitops-admin
kubectl create clusterrolebinding gitops-admin \
  --clusterrole=cluster-admin --serviceaccount=kube-system:gitops-admin

# 1. Dedicated Flux age key (one-time). Add its PUBLIC key to the repo manifest .sops.yaml.
age-keygen -o ~/.config/sops/age/edatw-lab-flux.txt

# 2. Configure + encrypt tfvars (k8s host/ca + github_token).
#    Leave kubernetes_token as the placeholder — tf-refresh-token fills it in.
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
just tf-encrypt-tfvars && rm terraform.tfvars

# 3. Configure + encrypt backend (R2 state).
cp backend.hcl.example backend.hcl
# edit backend.hcl
just tf-encrypt-backend && rm backend.hcl

# 4. Bootstrap Flux (tf-refresh-token mints a fresh token into the tfvars first).
just tf-init
just tf-refresh-token tf-plan
just tf-refresh-token tf-apply -auto-approve

# 5. Verify (export KUBECONFIG to the edatw-lab cluster first).
just flux-status
just flux-kustomizations
```

`just workflow` prints these steps; `just --list` shows all recipes.

## Gotchas

- **SOPS decryption silently fails** if the wrong/empty key is passed. The
  module accepts an empty `sops_age_key` (so `validate`/`plan` work without the
  key present), but apply needs the real key. After apply, confirm
  `just flux-check-sops` shows the `sops-age` secret.
- **`Makefile` is intentionally omitted.** The sibling cluster's `Makefile`
  includes `../../../makefiles/{terraform,talos}.mk`, which do not resolve from
  this `terraform/<env>/` location in the current `makefiles` submodule
  checkout. Use the self-contained `justfile` instead.

## Security Notes

- Never commit plaintext `terraform.tfvars` or `backend.hcl` (`.gitignore`d).
- Encrypted `.enc` files are safe to commit.
- The Flux private key (`edatw-lab-flux.txt`) is never committed; only its
  public key belongs in the repo manifest `.sops.yaml`.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gitops"></a> [gitops](#module\_gitops) | ../modules/gitops | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cert_manager_dns01_recursive_nameservers"></a> [cert\_manager\_dns01\_recursive\_nameservers](#input\_cert\_manager\_dns01\_recursive\_nameservers) | DNS server endpoints for DNS01 and DoH check requests | `list(string)` | <pre>[<br/>  "1.1.1.1:53",<br/>  "8.8.8.8:53"<br/>]</pre> | no |
| <a name="input_cert_manager_dns01_recursive_nameservers_only"></a> [cert\_manager\_dns01\_recursive\_nameservers\_only](#input\_cert\_manager\_dns01\_recursive\_nameservers\_only) | When true, cert-manager only queries the configured DNS resolvers for the ACME DNS01 self check | `bool` | `true` | no |
| <a name="input_cert_manager_enable_certificate_owner_ref"></a> [cert\_manager\_enable\_certificate\_owner\_ref](#input\_cert\_manager\_enable\_certificate\_owner\_ref) | When true, the certificate resource is set as owner of the TLS secret (auto-cleanup) | `bool` | `true` | no |
| <a name="input_cert_manager_enable_gateway_api"></a> [cert\_manager\_enable\_gateway\_api](#input\_cert\_manager\_enable\_gateway\_api) | Enable Gateway API integration in cert-manager (requires v1.15+) | `bool` | `true` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of cert-manager Helm chart to install | `string` | `"v1.19.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | `"edatw-lab"` | no |
| <a name="input_cluster_path"></a> [cluster\_path](#input\_cluster\_path) | Path in the repository where this cluster's Flux Kustomization root lives (repo-relative) | `string` | `"flux/clusters/edatw-lab"` | no |
| <a name="input_flux_components_extra"></a> [flux\_components\_extra](#input\_flux\_components\_extra) | Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller) | `list(string)` | `[]` | no |
| <a name="input_flux_namespace"></a> [flux\_namespace](#input\_flux\_namespace) | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| <a name="input_flux_network_policy"></a> [flux\_network\_policy](#input\_flux\_network\_policy) | Enable network policies for Flux controllers | `bool` | `true` | no |
| <a name="input_flux_operator_version"></a> [flux\_operator\_version](#input\_flux\_operator\_version) | Version of the Flux Operator Helm chart to install | `string` | `"0.33.0"` | no |
| <a name="input_flux_version"></a> [flux\_version](#input\_flux\_version) | Version of Flux controllers to deploy via FluxInstance | `string` | `"v2.7.3"` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to track for GitOps | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub repository owner (organization or user) | `string` | `"edatw"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (without owner) | `string` | `"infrastructure"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token for Flux GitOps (repo read; write if using image automation) | `string` | n/a | yes |
| <a name="input_kubernetes_cluster_ca_certificate"></a> [kubernetes\_cluster\_ca\_certificate](#input\_kubernetes\_cluster\_ca\_certificate) | Kubernetes cluster CA certificate (base64 encoded, as in kubeconfig certificate-authority-data) | `string` | n/a | yes |
| <a name="input_kubernetes_host"></a> [kubernetes\_host](#input\_kubernetes\_host) | Kubernetes API endpoint (e.g., https://100.64.0.10:6443) | `string` | n/a | yes |
| <a name="input_kubernetes_token"></a> [kubernetes\_token](#input\_kubernetes\_token) | Kubernetes authentication token (e.g., a gitops-admin ServiceAccount token) | `string` | n/a | yes |
| <a name="input_sops_age_key_path"></a> [sops\_age\_key\_path](#input\_sops\_age\_key\_path) | Path to the dedicated Flux age PRIVATE key file (deployed to the flux-system/sops-age secret). This is the private key (AGE-SECRET-KEY-...), not the public key. | `string` | `"~/.config/sops/age/flux-edatw-lab.txt"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cert_manager_namespace"></a> [cert\_manager\_namespace](#output\_cert\_manager\_namespace) | Namespace where cert-manager is installed |
| <a name="output_cluster_path"></a> [cluster\_path](#output\_cluster\_path) | Repo-relative path of the Flux Kustomization root |
| <a name="output_component_versions"></a> [component\_versions](#output\_component\_versions) | Installed component versions (cert-manager, Flux Operator, Flux) |
| <a name="output_flux_logs_commands"></a> [flux\_logs\_commands](#output\_flux\_logs\_commands) | Commands to view Flux controller logs |
| <a name="output_flux_namespace"></a> [flux\_namespace](#output\_flux\_namespace) | Namespace where Flux is installed |
| <a name="output_git_branch"></a> [git\_branch](#output\_git\_branch) | Git branch Flux tracks |
| <a name="output_git_repository"></a> [git\_repository](#output\_git\_repository) | Git repository URL Flux syncs from |
| <a name="output_next_steps"></a> [next\_steps](#output\_next\_steps) | Next steps after installation |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify the Flux installation |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
