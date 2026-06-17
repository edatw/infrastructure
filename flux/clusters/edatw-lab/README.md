# Flux Cluster — edatw-lab

GitOps configuration for the **edatw-lab** Talos/Tailscale cluster, managed by
Flux. Modelled on `shangkuei/infrastructure`'s `edatw-cluster`, adapted to
edatw-lab and rooted under `flux/` (not `kubernetes/`).

## Bootstrap chain

```
Terraform (terraform/gitops-edatw-lab):
  cert-manager (Helm) + flux-operator (Helm) + FluxInstance (SOPS)
      │
  FluxInstance syncs github.com/edatw/infrastructure
      │
  reconciles flux/clusters/edatw-lab  ← this directory
```

Terraform bootstraps Flux; this tree then **self-manages** it (the
`flux-operator` / `flux-instance` Kustomizations re-declare those components so
Flux owns them going forward).

## Layout — multi-source

The cluster-agnostic app bases are **not vendored** here. They are reused
from the public `shangkuei/infrastructure` repo via a second `GitRepository`
(`gitrepository-shangkuei.yaml`, pinned to a commit). Each app Kustomization
sources its base from there and applies edatw-lab deltas via `spec.patches`.

```
flux/
├── clusters/edatw-lab/   ← root + per-app Flux Kustomization CRs + remote GitRepository
├── base/                 ONLY the bases that back the local secret overlays:
│                           flux-instance, argocd, argocd-projects
└── overlays/             local, edatw-lab-specific (carry SOPS secrets):
                            flux-instance/edatw-lab, argocd-projects/edatw-lab
```

Sourced **remotely** from `shangkuei/infrastructure` (`./kubernetes/base/<app>`):
gateway-api, cilium, cert-manager, openebs, csi-driver-smb, snapshot-controller,
flux-operator. Apply order (root `kustomization.yaml` + each CR's `dependsOn`):
gateway-api → cilium / cert-manager → openebs / csi-driver-smb / snapshot-controller
→ flux-operator → flux-instance → argocd.

## edatw-lab deltas (applied via Flux `spec.patches`, not local copies)

- **cilium** — `MTU: 1230` (VXLAN over Tailscale) + chart `1.19.5` (patch on the remote base).
- **openebs** — remote base already defaults to LocalPV **hostpath**; no patch needed.
- **flux-instance** — kept local; sync URL `github.com/edatw/infrastructure`, path `flux/clusters/edatw-lab`.

> **Pin discipline:** `gitrepository-shangkuei.yaml` is pinned to a commit (the
> repo has no tags). Bump it deliberately after reviewing the upstream diff —
> it is a *different owner* (a personal repo), so for production you'd vendor
> these bases into an `edatw`-owned repo or publish them as OCI artifacts.

## Before this reconciles cleanly — TODO

1. **Generate the Flux secrets** (the encrypted blobs are intentionally not
   copied — they belonged to edatw-cluster's key):
   - `cd ../../overlays/flux-instance/edatw-lab && just sops-update-key && just setup`
   - then uncomment the two `secret-*.enc.yaml` resources there.
2. **ArgoCD KSOPS** (only if using ArgoCD): `cd ../../overlays/argocd-projects/edatw-lab && just sops-update-key && just argocd-ksops`, then uncomment its secret.
3. **ArgoCD app overlays** — `base/argocd-projects/edatw` Applications are
   patched to `argocd/<app>/overlays/edatw-lab`. Create those overlays in the
   repo's `argocd/` tree, or adjust the patches.
4. **Component ownership** — cilium/cert-manager/openebs are also touched by the
   talos bootstrap / Terraform. Letting Flux own them means dropping the talos
   `just cilium-install` step; reconcile the two so they don't fight.

## Operations

`just` recipes here: `flux-reconcile`, `flux-status`, `flux-logs`,
`secret-create`, `secret-edit`, `secret-view`, `sops-validate`.
Run `just --list`. Secrets use the Flux age key
`~/.config/sops/age/edatw-lab-flux.txt`.
