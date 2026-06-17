# EDATW Lab GitOps - Variables

# =============================================================================
# Kubernetes Connection (explicit credentials)
# =============================================================================

variable "kubernetes_host" {
  description = "Kubernetes API endpoint (e.g., https://100.64.0.10:6443)"
  type        = string
  sensitive   = true
}

variable "kubernetes_token" {
  description = "Kubernetes authentication token (e.g., a gitops-admin ServiceAccount token)"
  type        = string
  sensitive   = true
}

variable "kubernetes_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (base64 encoded, as in kubeconfig certificate-authority-data)"
  type        = string
  sensitive   = true
}

# =============================================================================
# GitHub
# =============================================================================

variable "github_owner" {
  description = "GitHub repository owner (organization or user)"
  type        = string
  default     = "edatw"
}

variable "github_repository" {
  description = "GitHub repository name (without owner)"
  type        = string
  default     = "infrastructure"
}

variable "github_token" {
  description = "GitHub personal access token for Flux GitOps (repo read; write if using image automation)"
  type        = string
  sensitive   = true
}

variable "github_branch" {
  description = "Git branch to track for GitOps"
  type        = string
  default     = "main"
}

# =============================================================================
# Cluster / Flux
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "edatw-lab"
}

variable "cluster_path" {
  description = "Path in the repository where this cluster's Flux Kustomization root lives (repo-relative)"
  type        = string
  default     = "flux/clusters/edatw-lab"
}

variable "flux_namespace" {
  description = "Namespace where Flux controllers will be installed"
  type        = string
  default     = "flux-system"
}

variable "flux_network_policy" {
  description = "Enable network policies for Flux controllers"
  type        = bool
  default     = true
}

variable "flux_components_extra" {
  description = "Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller)"
  type        = list(string)
  default     = []
}

variable "sops_age_key_path" {
  description = "Path to the dedicated Flux age PRIVATE key file (deployed to the flux-system/sops-age secret). This is the private key (AGE-SECRET-KEY-...), not the public key."
  type        = string
  default     = "~/.config/sops/age/flux-edatw-lab.txt"
}

# =============================================================================
# Component Versions
# =============================================================================

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart to install"
  type        = string
  default     = "v1.20.2"
}

variable "cert_manager_dns01_recursive_nameservers" {
  description = "DNS server endpoints for DNS01 and DoH check requests"
  type        = list(string)
  default     = ["1.1.1.1:53", "8.8.8.8:53"]
}

variable "cert_manager_dns01_recursive_nameservers_only" {
  description = "When true, cert-manager only queries the configured DNS resolvers for the ACME DNS01 self check"
  type        = bool
  default     = true
}

variable "cert_manager_enable_certificate_owner_ref" {
  description = "When true, the certificate resource is set as owner of the TLS secret (auto-cleanup)"
  type        = bool
  default     = true
}

variable "cert_manager_enable_gateway_api" {
  description = "Enable Gateway API integration in cert-manager (requires v1.15+)"
  type        = bool
  default     = true
}

variable "flux_operator_version" {
  description = "Version of the Flux Operator Helm chart to install"
  type        = string
  default     = "0.52.0"
}

variable "flux_version" {
  description = "Version of Flux controllers to deploy via FluxInstance"
  type        = string
  default     = "v2.8.8"
}
