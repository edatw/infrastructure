# EDATW Lab GitOps - Main Configuration
#
# Bootstraps Flux CD (cert-manager + Flux Operator + FluxInstance with SOPS) on
# the edatw-lab Kubernetes cluster via the gitops module.
#
# Providers are configured from explicit credentials supplied via encrypted
# terraform.tfvars (see terraform.tfvars.example for how to obtain them).

provider "kubernetes" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    token                  = var.kubernetes_token
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  load_config_file       = false
}

module "gitops" {
  source = "../modules/gitops"

  # Cluster configuration
  cluster_name = var.cluster_name
  cluster_path = var.cluster_path

  # GitHub configuration
  github_owner      = var.github_owner
  github_repository = var.github_repository
  github_token      = var.github_token
  github_branch     = var.github_branch

  # Flux configuration
  flux_namespace        = var.flux_namespace
  flux_network_policy   = var.flux_network_policy
  flux_components_extra = var.flux_components_extra

  # Dedicated Flux age PRIVATE key for in-cluster SOPS decryption.
  # Empty (when the file is absent) keeps `terraform validate`/plan working;
  # the key must exist for apply or Flux cannot decrypt manifests.
  sops_age_key = fileexists(pathexpand(var.sops_age_key_path)) ? file(pathexpand(var.sops_age_key_path)) : ""

  # Component versions
  cert_manager_version                          = var.cert_manager_version
  cert_manager_dns01_recursive_nameservers      = var.cert_manager_dns01_recursive_nameservers
  cert_manager_dns01_recursive_nameservers_only = var.cert_manager_dns01_recursive_nameservers_only
  cert_manager_enable_certificate_owner_ref     = var.cert_manager_enable_certificate_owner_ref
  cert_manager_enable_gateway_api               = var.cert_manager_enable_gateway_api
  flux_operator_version                         = var.flux_operator_version
  flux_version                                  = var.flux_version
}
