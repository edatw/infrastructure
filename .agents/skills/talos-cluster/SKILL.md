---
name: talos-cluster
description: Configure the `talos-cluster` Terraform module (generates Talos Linux machine configurations + per-node patches for a Tailscale-networked Kubernetes cluster). Use when the user is defining control-plane/worker nodes, adding Talos extensions, configuring OpenEBS Mayastor or ZFS LocalPV storage, picking a CNI, or wiring SBC overlays.
---

# talos-cluster module

Generates Talos machine configuration files (control-plane + worker per-node configs, patches,
Tailscale extension docs, talosconfig) for a Tailscale-meshed Kubernetes cluster. Output is
`local_file`s — `terraform apply` writes YAMLs to disk; `talosctl apply-config` deploys them.

Source repo: `github.com/shangkuei/terraform-modules//talos-cluster`. Pin via `?ref=<tag>`.

## Canonical block

```hcl
module "cluster" {
  source = "git::https://github.com/shangkuei/terraform-modules.git//talos-cluster?ref=v1.0.0"

  cluster_name = "my-cluster"

  control_plane_nodes = {
    cp-01 = {
      tailscale_ipv4 = "100.64.0.10"
      install_disk   = "/dev/sda"
      hostname       = "cp-01"
    }
  }

  worker_nodes = {
    worker-01 = {
      tailscale_ipv4 = "100.64.0.20"
      install_disk   = "/dev/sda"
      hostname       = "worker-01"
    }
  }

  tailscale_tailnet  = "example-org"
  tailscale_auth_key = var.tailscale_auth_key

  talos_version      = "v1.8.0"
  kubernetes_version = "v1.31.0"
}
```

## Required inputs

- `cluster_name`.
- `control_plane_nodes` — `map(object)` keyed by short node id. Required per node: `tailscale_ipv4`, `install_disk`.

## Common optional inputs

- `worker_nodes` (default `{}`) — same shape as control-plane plus storage fields (see below).
- `tailscale_tailnet`, `tailscale_auth_key` — required if you want the Tailscale extension and MagicDNS hostnames; leave empty to skip.
- `cluster_endpoint` — `https://<tailscale-ip>:6443`. Defaults to the first control-plane's Tailscale IP.
- `talos_version` (default `"v1.8.0"`), `kubernetes_version` (default `"v1.31.0"`).
- `cni_name` (default `"flannel"`) — also `"cilium"`, `"calico"`, `"none"`. When `"cilium"`, `cilium_helm_values` is rendered to `cilium-values.yaml`.
- `enable_kubeprism` (default `true`), `kubeprism_port` (default `7445`) — local API LB for HA.
- `pod_cidr`, `service_cidr`, `dns_domain` — standard CNI/cluster networking knobs.
- `cert_sans` (default `[]`) — additional API SANs (Tailscale IPs auto-added).
- `additional_control_plane_patches`, `additional_worker_patches` — extra YAML patches merged in.
- `wipe_install_disk` (default `false`) — wipe before install (destructive).
- `openebs_hostpath_enabled` (default `false`) — global LocalPV Hostpath toggle (Pod Security exemption + kubelet mount).

### Per-worker storage knobs

- `openebs_storage` (default `false`) — enable Mayastor: adds node labels
  (`openebs.io/engine=mayastor`, `openebs.io/storage-node=true`) and hugepages. Mayastor uses raw
  block devices via SPDK; **do not partition or format `openebs_disk`** — Talos doesn't touch it,
  the Kubernetes DiskPool resource does.
- `openebs_disk` — raw device for Mayastor (e.g., `/dev/sdb`, `/dev/disk/by-id/wwn-…`). Must be
  empty/unpartitioned; wipe with `talosctl wipe disk <part> --drop-partition` if needed.
- `openebs_hugepages_2mi` (default `1024` ≈ 2 GiB) — Mayastor requirement.
- `zfs_pools` (default `[]`) — list of `{ name, disks, type }` where
  `type ∈ { "", "mirror", "raidz", "raidz2", "raidz3" }`. Adds the `openebs.io/zfs=true` label,
  an `/var/openebs/encr-keys` kubelet mount, and emits `worker-<node>-zfs-pool-setup.sh` to run
  via `talosctl … run -`. **Requires `siderolabs/zfs` in `extensions`** plus the `zfs` kernel
  module (the module wires the kernel module automatically when the extension is present).

### Per-node overlays (SBC)

```hcl
overlay = {
  image = "siderolabs/sbc-raspberrypi"   # or sbc-rockchip, etc.
  name  = "rpi_5"                        # rpi_4, rpi_generic, rock4c-plus, orangepi-5, ...
}
```

## Key outputs

- `generated_configs` — map of file paths (per-node configs, patches, tailscale docs).
- `client_configuration`, `client_configs` (**sensitive**) — talosconfig content/path.
- `machine_secrets` (**sensitive**) — Talos PKI material; back this up.
- `installer_images`, `schematic_ids` — per-node Image Factory URLs and schematics (used during install).
- `cilium_values_path` — only when `cni_name = "cilium"`.
- `cluster_info`, `node_summary`, `tailscale_config`, `troubleshooting` — diagnostic summaries.

## Gotchas

- **Tailscale-first networking is assumed.** Cluster endpoint, KubePrism, API SANs, and node IPs
  all use Tailscale addresses (`100.64.0.0/10` range). Bootstrapping uses a node's `physical_ip`
  for the initial `talosctl apply-config --insecure`; everything afterward uses Tailscale. If a
  node never joins the tailnet, the cluster is unreachable.
- **Mayastor disk handling moved.** Previously the module created a UserVolumeConfig and a kubelet
  extraMount; as of commit `e677630` it does neither — Mayastor consumes raw devices via SPDK and
  DiskPool creation happens in Kubernetes (outside this module). If you see references to
  `worker_openebs_volume` or a Mayastor extraMount in the module, you're on an old ref — bump the
  `?ref=` and re-pull the skill.
- **ZFS extraMounts are per-node, not global.** The `/var/openebs/encr-keys` bind mount is
  injected into `worker_patches` only when that worker has `zfs_pools` set. Don't add it manually
  to `additional_worker_patches`.
- **`zfs_pools` does not create pools by itself.** It only emits
  `worker-<node>-zfs-pool-setup.sh`. Run the script through `talosctl … run -` after the node is
  up. The pools must exist before OpenEBS ZFS LocalPV will schedule volumes.
- **`extensions` defaults to `["siderolabs/tailscale"]`.** Setting `extensions = [...]` *replaces*
  the default — re-include `"siderolabs/tailscale"` unless you genuinely want a non-Tailscale node.
- **`wipe_install_disk = true` is destructive on apply** — every node wipes its install disk. Use
  only on greenfield deploys.
- **Apply is two-phase.** `terraform apply` writes files only; you still need `talosctl
  apply-config --insecure`, `talosctl bootstrap`, `talosctl health` (see module README "Deployment
  Workflow"). Don't expect the cluster to exist after `terraform apply`.
- **`cilium_helm_values` defaults differ from the module README example.** The default already
  sets `kubeProxyReplacement = "true"`, `k8sServiceHost = "localhost"`, `k8sServicePort = 6443`
  (note: not the KubePrism port). Override `k8sServicePort` to `7445` if you want Cilium to talk
  to KubePrism specifically.
