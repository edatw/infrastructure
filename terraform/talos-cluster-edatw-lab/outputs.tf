# EDATW Cluster - Outputs
#
# Expose outputs from the talos-cluster module.

# =============================================================================
# Generated Files
# =============================================================================

output "generated_configs" {
  description = "Paths to all generated machine configuration files"
  value       = module.talos_cluster.generated_configs
}

output "client_configs" {
  description = "Client configuration files for cluster access"
  value       = module.talos_cluster.client_configs
}

output "cilium_values_path" {
  description = "Path to generated Cilium Helm values file (only when Cilium CNI is enabled)"
  value       = module.talos_cluster.cilium_values_path
}

output "output_directory" {
  description = "Directory containing all generated configuration files"
  value       = module.talos_cluster.output_directory
}

# =============================================================================
# Cluster Information
# =============================================================================

output "cluster_info" {
  description = "Cluster configuration summary"
  value       = module.talos_cluster.cluster_info
}

output "node_summary" {
  description = "Summary of cluster nodes"
  value       = module.talos_cluster.node_summary
}

output "tailscale_config" {
  description = "Tailscale network configuration"
  value       = module.talos_cluster.tailscale_config
}

# =============================================================================
# Machine Secrets (Sensitive)
# =============================================================================

output "machine_secrets" {
  description = "Talos machine secrets for cluster operations"
  value       = module.talos_cluster.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration for cluster management"
  value       = module.talos_cluster.client_configuration
  sensitive   = true
}

# =============================================================================
# Image Factory Information
# =============================================================================

output "installer_images" {
  description = "Talos installer image URLs for each node"
  value       = module.talos_cluster.installer_images
}

output "schematic_ids" {
  description = "Image factory schematic IDs for each unique extension+overlay combination"
  value       = module.talos_cluster.schematic_ids
}

# =============================================================================
# Troubleshooting Information
# =============================================================================

output "troubleshooting" {
  description = "Common troubleshooting commands"
  value       = module.talos_cluster.troubleshooting
}

# =============================================================================
# Deployment Commands
# =============================================================================

output "deployment_commands" {
  description = "Makefile commands for cluster deployment"
  value = {
    apply_configs     = "make talos-apply"
    bootstrap_cluster = "make talos-bootstrap"
    check_health      = "make talos-health"
    list_nodes        = "make talos-nodes"
    list_pods         = "make talos-pods"
    show_status       = "make talos-status"
  }
}
