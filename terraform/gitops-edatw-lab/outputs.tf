# EDATW Lab GitOps - Outputs
#
# Re-expose the gitops module's outputs for diagnostics.

output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = module.gitops.flux_namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = module.gitops.cert_manager_namespace
}

output "git_repository" {
  description = "Git repository URL Flux syncs from"
  value       = module.gitops.git_repository
}

output "git_branch" {
  description = "Git branch Flux tracks"
  value       = module.gitops.git_branch
}

output "cluster_path" {
  description = "Repo-relative path of the Flux Kustomization root"
  value       = module.gitops.cluster_path
}

output "component_versions" {
  description = "Installed component versions (cert-manager, Flux Operator, Flux)"
  value       = module.gitops.component_versions
}

output "verification_commands" {
  description = "Commands to verify the Flux installation"
  value       = module.gitops.verification_commands
}

output "flux_logs_commands" {
  description = "Commands to view Flux controller logs"
  value       = module.gitops.flux_logs_commands
}

output "next_steps" {
  description = "Next steps after installation"
  value       = <<-EOT
    Flux is bootstrapped on ${module.gitops.cluster_name}.

    1. Verify components:
       kubectl -n ${module.gitops.cert_manager_namespace} get pods
       kubectl -n ${module.gitops.flux_namespace} get pods

    2. Confirm the SOPS key (Flux decryption):
       kubectl -n ${module.gitops.flux_namespace} get secret sops-age

    3. Check Git sync + reconciliation:
       kubectl -n ${module.gitops.flux_namespace} get gitrepository
       kubectl -n ${module.gitops.flux_namespace} get kustomization -w

    4. Add manifests under ${module.gitops.cluster_path} on branch ${module.gitops.git_branch};
       Flux reconciles automatically.
  EOT
}
