# EDATW Lab Cluster

Terraform environment for the EDA Taiwan **lab** Talos Linux Kubernetes cluster with Tailscale networking.

## Overview

Uses the `talos-cluster` module to generate Talos machine configurations.
The cluster operates over a Tailscale mesh network for secure, private
node-to-node communication.

## Features

- **Tailscale Integration**: All cluster communication via Tailscale mesh network
- **KubePrism**: Local load balancer for high-availability API access (port 7445)
- **Cilium CNI**: kube-proxy replacement, Gateway API, Hubble observability
- **OpenEBS Hostpath**: LocalPV storage enabled
- **SOPS Encryption**: Secrets managed with age encryption

## Network Design Notes

### Cilium BPF masquerade is disabled

`bpf.masquerade` is set to `false` because this is a Tailscale-first cluster:

- **Interface ambiguity**: BPF masquerade needs a predictable primary egress
  interface and IP. Tailscale routes traffic through `tailscale0`, which BPF
  masquerade may misidentify.
- **DNS forwarding**: With BPF masquerade disabled, the Talos config keeps
  `forwardKubeDNSToHost = true`, which is required for pods to resolve
  Tailscale MagicDNS names (`<hostname>.<tailnet>.ts.net`).
- **iptables fallback**: Cilium falls back to iptables-based masquerading,
  which handles the Tailscale interface correctly.

Do **not** enable `bpf.masquerade` unless Tailscale networking is removed.

### Cilium routing mode: VXLAN tunnel

Cilium runs in **VXLAN tunnel mode** (`routingMode: tunnel`, `tunnelProtocol:
vxlan` — the default). Cross-node pod traffic is encapsulated and sent to the
remote node's Tailscale IP over `tailscale0`. This is deliberate for a
Tailscale-first cluster: tunnel mode makes **no assumptions about the underlay**
(pod CIDRs need not be routable between nodes), so it works whether nodes are
LAN-local or remote across the tailnet.

Alternatives, compared over the 1280-byte Tailscale transport:

| Mode | Encap overhead | Pod MTU | Underlay requirement | Complexity |
|------|----------------|---------|----------------------|------------|
| **VXLAN tunnel** (current) | ~50 B | 1230 | none (any L3) | lowest (default) |
| Geneve tunnel | ~50 B+ | ~1230 | none | low |
| Native routing | 0 | 1280 | pod CIDRs routable node-to-node | high on a mesh |

- **VXLAN (current)** — zero underlay assumptions; the only cost is the ~50 B
  overhead and the 1230 MTU (see the next note). Robust regardless of where
  nodes sit.
- **Native routing** (`routingMode: native`) — drops the 50 B (pod MTU back to
  1280) and a layer of encapsulation, and sidesteps the VXLAN-MTU class of
  problem. On a Tailscale mesh it requires advertising each node's pod CIDR as a
  Tailscale subnet route (with route approval / ACLs) or running Cilium BGP —
  more moving parts, and a misadvertised route fails silently.
  `auto-direct-node-routes` only works if all nodes share an L2 segment, which
  the Tailscale-first design does not assume.
- **Geneve** — same overhead as VXLAN; switch only if a Geneve-only feature is
  needed.

Node-to-node traffic is encrypted by Tailscale's WireGuard in every mode, so
Cilium transparent encryption stays disabled.

### Cilium MTU is pinned to 1230 for VXLAN over Tailscale

`MTU` is set to `1230` in `cilium_helm_values` because Cilium runs in **VXLAN
tunnel mode** and encapsulates cross-node pod traffic over the Tailscale
interface (`tailscale0`, MTU **1280**):

- **VXLAN overhead**: encapsulation adds 50 bytes, so the pod/tunnel MTU must be
  `1280 - 50 = 1230`. An encapsulated full-size pod packet (1230 + 50 = 1280)
  then still fits through `tailscale0`.
- **Why auto-detect fails**: without an explicit `MTU`, Cilium auto-detects 1280
  and applies it to `cilium_vxlan` and the pod veths with no headroom.
  Encapsulated packets become 1330 bytes and are dropped crossing `tailscale0`.
  Small packets (DNS) still pass, so the symptom is selective — TLS handshakes
  and bulk cross-node transfers fail (connection resets / timeouts in
  `cilium connectivity test`) while basic connectivity and `cilium-health`
  (small probes) look healthy.

Keep `MTU` at `1230` while the cluster runs Cilium VXLAN over Tailscale. If the
transport MTU or routing mode changes, recompute (transport MTU − 50 for VXLAN,
or drop the override entirely when not tunneling).

### Machine patches for monitoring

The `additional_control_plane_patches` and `additional_worker_patches` enable
Prometheus-based monitoring:

- **`rotate-server-certificates: true`** (all nodes) — Kubelet defaults to
  self-signed serving certificates. This flag makes kubelet request serving
  certs from the cluster CA and auto-rotate them. Without it, metrics-server
  and Prometheus fail to scrape kubelet metrics over HTTPS (`kubectl top`
  returns TLS errors).
- **`bind-address: "0.0.0.0"` on controller-manager and scheduler** (control
  plane only) — Both components default to binding their metrics endpoints on
  `127.0.0.1`. Prometheus pods can only reach nodes via pod/Tailscale IPs, not
  localhost. This exposes kube-controller-manager (`:10257`) and
  kube-scheduler (`:10259`) metrics for scraping.

## Prerequisites

- Terraform >= 1.6.0
- [talosctl](https://www.talos.dev/latest/introduction/getting-started/)
- [just](https://just.systems/) task runner
- [SOPS](https://github.com/getsops/sops) + [age](https://age-encryption.org/)
- Tailscale account with [auth key](https://login.tailscale.com/admin/settings/keys)

## Quick Start

```bash
# 1. Generate age key (one-time)
age-keygen -o ~/.config/sops/age/talos-cluster-edatw-lab.txt

# 2. Update .sops.yaml with the public key
just sops-init-config

# 3. Configure and encrypt tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
just tf-encrypt-tfvars && rm terraform.tfvars

# 4. Configure and encrypt backend
cp backend.hcl.example backend.hcl
# Edit backend.hcl with R2 credentials
just tf-encrypt-backend && rm backend.hcl

# 5. Deploy
just tf-init
just tf-apply -auto-approve
just talos-apply all --insecure
# Wait for nodes to join Tailscale
just talos-bootstrap
just talos-health
```

## Bootstrap Gotchas

### Node stays `NotReady` — pending kubelet-serving CSR

After `just talos-bootstrap`, the control-plane node can stay `NotReady`
indefinitely. `talosctl logs controller-runtime` shows the runtime controller
failing in a loop:

```text
controller failed {"controller": "k8s.KubeletStaticPodController",
  "error": "...https://127.0.0.1:10250/pods/...: remote error: tls: internal error"}
new diagnostic {"id": "kubelet-csr",
  "message": "kubelet server certificate rotation is enabled, but CSR is not approved"}
```

**Cause:** the machine config sets `rotate-server-certificates: true` (required so
Prometheus/metrics-server can scrape kubelet over HTTPS — see Network Design
Notes). Kubelet then requests a **serving** certificate via a CSR. Talos
auto-approves kubelet *client* CSRs but **never** *serving* CSRs (by design), so
the CSR stays `Pending`, kubelet has no valid serving cert on `:10250`, and the
node never reaches Ready.

**Fix — approve the pending serving CSR:**

```bash
just talos-kubeconfig
export KUBECONFIG=$PWD/generated/kubeconfig

# The generated kubeconfig points at KubePrism (127.0.0.1:7445), which only works
# on-node. From a workstation, target the node API directly (admin client cert is
# in the kubeconfig; skip server-cert verify to sidestep SANs):
NODE=192.168.1.18    # cp-01 physical IP, or its Tailscale IP
kubectl --server "https://$NODE:6443" --insecure-skip-tls-verify get csr
kubectl --server "https://$NODE:6443" --insecure-skip-tls-verify \
  certificate approve <csr-name>   # signerName: kubernetes.io/kubelet-serving
```

**Recurring:** the serving cert rotates periodically; each rotation creates a new
`Pending` CSR. For unattended operation, deploy a serving-CSR approver (e.g.
[postfinance/kubelet-csr-approver](https://github.com/postfinance/kubelet-csr-approver))
rather than approving by hand.

### Node still `NotReady` — CNI not installed

Once the CSR is approved, the node stays `NotReady` with
`cni plugin not initialized` (CoreDNS pods `Pending`) until the **Cilium CNI** is
installed. Deploy Cilium using the generated `generated/cilium-values.yaml`.

## Just Commands

### Terraform (shared — `makefiles/terraform.just`)

| Command | Description |
|---------|-------------|
| `just tf-init` | Initialize Terraform with encrypted backend |
| `just tf-plan` | Generate execution plan |
| `just tf-apply -auto-approve` | Apply (generate cluster configurations) |
| `just tf-destroy` | Destroy infrastructure (with confirmation) |
| `just tf-validate` | Validate Terraform configuration |
| `just tf-fmt` | Format Terraform files |
| `just tf-output` | Show Terraform outputs |
| `just tf-upgrade` | Upgrade Terraform providers |
| `just tf-clean` | Remove `.terraform`, state, and `generated/` |
| `just tf-encrypt-tfvars` | Encrypt `terraform.tfvars` |
| `just tf-encrypt-backend` | Encrypt `backend.hcl` |
| `just tf-edit-tfvars` / `tf-edit-backend` | Edit encrypted tfvars/backend |

### SOPS (shared — `makefiles/sops.just`)

| Command | Description |
|---------|-------------|
| `just sops-encrypt --file <file>` | Encrypt a file in-place |
| `just sops-decrypt --file <file>` | Decrypt a file to stdout |
| `just sops-edit --file <file>` | Edit an encrypted file |
| `just sops-keygen` | Generate an age key pair |
| `just sops-init-config` | Generate key + update `.sops.yaml` |
| `just sops-info` | Show SOPS key/config info |
| `just sops-validate` | Validate all encrypted files decrypt |

### Talos Cluster (shared — `makefiles/talos.just`)

| Command | Description |
|---------|-------------|
| `just talos-apply` | Apply configs to all nodes |
| `just talos-apply cp-01 --insecure` | Apply to specific node |
| `just talos-bootstrap` | Bootstrap Kubernetes cluster |
| `just talos-kubeconfig` | Retrieve kubeconfig |
| `just talos-health` | Check cluster health |
| `just talos-nodes` | List cluster nodes |
| `just talos-pods` | List all pods |
| `just talos-status` | Complete cluster status |
| `just talos-upgrade-k8s v1.32.0` | Upgrade Kubernetes |
| `just talos-upgrade <ip[,ip…]> --image <url>` | Upgrade Talos on node(s) |
| `just talos-dashboard <ip[,ip…]>` | Open Talos dashboard |
| `just talos-logs <ip[,ip…]> <svc>` | View node service logs |
| `just talos-reset <ip[,ip…]>` | Reset node(s) (destructive) |
| `just talos-reboot <ip[,ip…]>` | Reboot node(s) |

### Workflow

| Command | Description |
|---------|-------------|
| `just all` | Complete cluster setup end-to-end |
| `just workflow` | Show setup workflow steps |
| `just clean` | Remove generated files and Terraform state |

## Node Recovery (Re-flashing Wiped Nodes)

Use this when a node has been wiped (`talosctl reset --wipe-mode all`) or its
machine-config secrets no longer match the talosconfig — e.g. `just bootstrap`
fails with `x509: certificate signed by unknown authority`.

### Why a wiped node can't be recovered over the API

Talos' secured API is **mutual TLS**. `bootstrap`, `reset`, and `apply-config`
(secured) all require a talosconfig whose client cert is signed by the **node's**
CA. Consequences:

- If the Terraform state was re-created (new `machine_secrets`), the freshly
  generated talosconfig no longer matches a node provisioned from older secrets.
  Bootstrap fails with `certificate signed by unknown authority`.
- `reset --insecure` (maintenance API) only works in **maintenance mode**. A
  configured node rejects it with `tls: certificate required`.
- A wiped SBC has no OS on its system disk, so it cannot return to maintenance
  mode on its own — its **boot media must be re-flashed** from a workstation.

There is no unauthenticated remote wipe by design. Recovery is: **re-flash boot
media → boot into maintenance → `apply-config` (installs) → verify → bootstrap**.

### Hardware / image map

Boot images come from the [Image Factory](https://factory.talos.dev/); schematic
IDs are in `terraform output schematic_ids`. Install disks are pinned by-id in the
generated `*-patch.yaml` files.

| Node | Hardware | Arch | Boot image (factory) | Install disk |
|------|----------|------|----------------------|--------------|
| cp-01 | Raspberry Pi 4 8G | arm64 | `metal-arm64.raw.xz` (schematic `04d4078b…`) | USB SSD (`/dev/disk/by-id/wwn-…`) |
| worker-01..03 | ZimaBoard 2 16G | amd64 SecureBoot | `metal-amd64-secureboot.iso` (schematic `c10360c1…`) | eMMC (`/dev/disk/by-id/mmc-…`) |
| worker-04 | ZimaBlade 16G | amd64 SecureBoot | `metal-amd64-secureboot.iso` | eMMC (`/dev/disk/by-id/mmc-…`) |

> `talos-apply` takes the node name positionally; any extra flags pass straight
> through to `talosctl` — e.g. `just talos-apply cp-01 --insecure`. Pass several
> nodes comma-separated (`just talos-apply cp-01,worker-01 --insecure`), or `all`
> (the default) to apply to every node: `just talos-apply all --insecure`.

### 1. Flash boot media (on the workstation)

Raspberry Pi (arm64) — flash to the boot device (SD card, or the USB SSD if the
Pi USB-boots):

```bash
curl -L -o ~/Downloads/talos-cp01-arm64.raw.xz \
  "https://factory.talos.dev/image/<arm64-schematic>/<version>/metal-arm64.raw.xz"
diskutil list external physical          # identify the target disk — CHECK CAREFULLY
diskutil unmountDisk /dev/diskN
xz -dc ~/Downloads/talos-cp01-arm64.raw.xz | sudo dd of=/dev/rdiskN bs=4m
#   macOS/BSD dd has no status=progress — press Ctrl+T for progress
diskutil eject /dev/diskN
```

ZimaBoard / ZimaBlade (amd64 SecureBoot) — write the ISO to a USB stick and boot
from it (live maintenance system; SecureBoot must be enabled in UEFI with keys
enrolled):

```bash
curl -L -o ~/Downloads/talos-worker-amd64-sb.iso \
  "https://factory.talos.dev/image/<amd64-schematic>/<version>/metal-amd64-secureboot.iso"
diskutil list external physical
diskutil unmountDisk /dev/diskN
sudo dd if=~/Downloads/talos-worker-amd64-sb.iso of=/dev/rdiskN bs=4m
diskutil eject /dev/diskN
```

### 2. Boot → confirm maintenance mode → probe disks

```bash
export TALOSCONFIG=$PWD/generated/talosconfig
talosctl version  --insecure -n <node-ip> -e <node-ip>   # server responds = maintenance
talosctl get disks --insecure -n <node-ip> -e <node-ip>  # confirm the system disk
```

### 3. Install (apply-config writes Talos to the install disk, then reboots)

```bash
just talos-apply cp-01 --insecure   # base config + patches, insecure
# workers: just talos-apply worker-01 --insecure   (… worker-04)
```

### 4. Verify

After the node reboots (~1–3 min) it should answer with **your** CA (no cert
error) and join the tailnet:

```bash
talosctl -n <node-ip> -e <node-ip> version          # no "unknown authority"
talosctl -n <node-ip> -e <node-ip> get machineconfig
tailscale status | grep edatw-lab                    # node appears on the tailnet
```

### 5. Bootstrap (once, on the first control plane only)

```bash
just talos-bootstrap
just talos-health
just talos-kubeconfig && kubectl --kubeconfig generated/kubeconfig get nodes -o wide
```

## Security Notes

- **Never commit** unencrypted `terraform.tfvars` or `backend.hcl`
- **Encrypted files** (`.enc`) are safe to commit
- **Age key**: `~/.config/sops/age/talos-cluster-edatw-lab.txt`
- **Tailscale auth key** should use tags for ACL management
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_talos_cluster"></a> [talos\_cluster](#module\_talos\_cluster) | ../modules/talos-cluster | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_control_plane_patches"></a> [additional\_control\_plane\_patches](#input\_additional\_control\_plane\_patches) | Additional YAML patches to apply to control plane nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_additional_worker_patches"></a> [additional\_worker\_patches](#input\_additional\_worker\_patches) | Additional YAML patches to apply to worker nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_cert_sans"></a> [cert\_sans](#input\_cert\_sans) | Additional Subject Alternative Names (SANs) for API server certificate (Tailscale IPs will be added automatically) | `list(string)` | `[]` | no |
| <a name="input_cilium_helm_values"></a> [cilium\_helm\_values](#input\_cilium\_helm\_values) | Helm values for Cilium CNI deployment (only used when cni\_name = 'cilium'). Map of values to customize Cilium installation. | `any` | <pre>{<br/>  "hubble": {<br/>    "enabled": false,<br/>    "relay": {<br/>      "enabled": false<br/>    },<br/>    "ui": {<br/>      "enabled": false<br/>    }<br/>  },<br/>  "ipv6": {<br/>    "enabled": false<br/>  },<br/>  "k8sServiceHost": "localhost",<br/>  "k8sServicePort": 6443,<br/>  "kubeProxyReplacement": "true",<br/>  "operator": {<br/>    "replicas": 1<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint using Tailscale IP (e.g., https://100.64.0.10:6443). Set to first control plane's Tailscale IP. | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_cni_name"></a> [cni\_name](#input\_cni\_name) | CNI plugin name (flannel, cilium, calico, or none) | `string` | `"flannel"` | no |
| <a name="input_control_plane_nodes"></a> [control\_plane\_nodes](#input\_control\_plane\_nodes) | Map of control plane nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    secure_boot    = optional(bool, false)                            # SecureBoot: UKI installer + TPM-sealed disk encryption (requires x86/UEFI SecureBoot + TPM 2.0)<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)<br/>    overlay = optional(object({<br/>      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")<br/>      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")<br/>    }))<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>  }))</pre> | n/a | yes |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | Kubernetes DNS domain | `string` | `"cluster.local"` | no |
| <a name="input_enable_kubeprism"></a> [enable\_kubeprism](#input\_enable\_kubeprism) | Enable KubePrism for high-availability Kubernetes API access | `bool` | `true` | no |
| <a name="input_gateway_api_version"></a> [gateway\_api\_version](#input\_gateway\_api\_version) | Gateway API CRD release tag baked into the Talos config when Cilium Gateway API is enabled. Latest stable from kubernetes-sigs/gateway-api; bump with `just gateway-api-bump`. | `string` | `"v1.5.1"` | no |
| <a name="input_kubeprism_port"></a> [kubeprism\_port](#input\_kubeprism\_port) | Port for KubePrism local load balancer | `number` | `7445` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version (e.g., v1.31.0) | `string` | `"v1.31.0"` | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | Additional Kubernetes node labels to apply to all nodes | `map(string)` | `{}` | no |
| <a name="input_openebs_hostpath_enabled"></a> [openebs\_hostpath\_enabled](#input\_openebs\_hostpath\_enabled) | Enable OpenEBS LocalPV Hostpath support (adds Pod Security admission control exemptions and kubelet hostpath mounts for openebs namespace) | `bool` | `false` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Pod network CIDR block | `string` | `"10.244.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Service network CIDR block | `string` | `"10.96.0.0/12"` | no |
| <a name="input_tailscale_auth_key"></a> [tailscale\_auth\_key](#input\_tailscale\_auth\_key) | Tailscale authentication key for joining the tailnet (use reusable, tagged key) | `string` | `""` | no |
| <a name="input_tailscale_tailnet"></a> [tailscale\_tailnet](#input\_tailscale\_tailnet) | Tailscale tailnet name for MagicDNS hostnames (e.g., 'example-org' for example-org.ts.net). Leave empty to skip MagicDNS hostname generation. | `string` | `""` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (e.g., v1.8.0) | `string` | `"v1.8.0"` | no |
| <a name="input_use_dhcp_for_physical_interface"></a> [use\_dhcp\_for\_physical\_interface](#input\_use\_dhcp\_for\_physical\_interface) | Use DHCP for physical network interface configuration | `bool` | `true` | no |
| <a name="input_wipe_install_disk"></a> [wipe\_install\_disk](#input\_wipe\_install\_disk) | Wipe the installation disk before installing Talos | `bool` | `false` | no |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Map of worker nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    secure_boot    = optional(bool, false)                            # SecureBoot: UKI installer + TPM-sealed disk encryption (requires x86/UEFI SecureBoot + TPM 2.0)<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)<br/>    overlay = optional(object({<br/>      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")<br/>      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")<br/>    }))<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>    # OpenEBS Replicated Storage configuration<br/>    openebs_storage       = optional(bool, false)  # Enable OpenEBS storage on this node<br/>    openebs_disk          = optional(string)       # Storage disk device (e.g., /dev/nvme0n1, /dev/sdb)<br/>    openebs_hugepages_2mi = optional(number, 1024) # Number of 2MiB hugepages (1024 = 2GiB, required for Mayastor)<br/>    # OpenEBS ZFS LocalPV configuration - supports multiple pools per node<br/>    zfs_pools = optional(list(object({<br/>      name  = string               # Pool name (e.g., "zpool", "tank", "data")<br/>      disks = list(string)         # Disk devices (e.g., ["/dev/sdb"] or ["/dev/sdb", "/dev/sdc"])<br/>      type  = optional(string, "") # Pool type: "" (single/stripe), "mirror", "raidz", "raidz2", "raidz3"<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cilium_values_path"></a> [cilium\_values\_path](#output\_cilium\_values\_path) | Path to generated Cilium Helm values file (only when Cilium CNI is enabled) |
| <a name="output_client_configs"></a> [client\_configs](#output\_client\_configs) | Client configuration files for cluster access |
| <a name="output_client_configuration"></a> [client\_configuration](#output\_client\_configuration) | Talos client configuration for cluster management |
| <a name="output_cluster_info"></a> [cluster\_info](#output\_cluster\_info) | Cluster configuration summary |
| <a name="output_deployment_commands"></a> [deployment\_commands](#output\_deployment\_commands) | Makefile commands for cluster deployment |
| <a name="output_generated_configs"></a> [generated\_configs](#output\_generated\_configs) | Paths to all generated machine configuration files |
| <a name="output_installer_images"></a> [installer\_images](#output\_installer\_images) | Talos installer image URLs for each node |
| <a name="output_machine_secrets"></a> [machine\_secrets](#output\_machine\_secrets) | Talos machine secrets for cluster operations |
| <a name="output_node_summary"></a> [node\_summary](#output\_node\_summary) | Summary of cluster nodes |
| <a name="output_output_directory"></a> [output\_directory](#output\_output\_directory) | Directory containing all generated configuration files |
| <a name="output_schematic_ids"></a> [schematic\_ids](#output\_schematic\_ids) | Image factory schematic IDs for each unique extension+overlay combination |
| <a name="output_tailscale_config"></a> [tailscale\_config](#output\_tailscale\_config) | Tailscale network configuration |
| <a name="output_troubleshooting"></a> [troubleshooting](#output\_troubleshooting) | Common troubleshooting commands |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
