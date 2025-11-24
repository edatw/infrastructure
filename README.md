# EDA Taiwan Infrastructure

> Infrastructure as Code for EDA Taiwan's Kubernetes applications using ArgoCD, Kustomize, and Terraform

[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io/cd/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![SOPS](https://img.shields.io/badge/SOPS-Encrypted-4B32C3?logo=mozilla)](https://github.com/mozilla/sops)

## Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing EDA Taiwan's Kubernetes applications and supporting infrastructure. It leverages:

- **ArgoCD** for GitOps continuous delivery of Kubernetes applications
- **Kustomize** for Kubernetes-native configuration management
- **SOPS/Age** for secrets encryption and management
- **Terraform** for infrastructure provisioning (Cloudflare, networking, storage)

### Design Goals

- **GitOps Workflow**: All changes deployed through version-controlled commits
- **Security by Default**: Encrypted secrets, least privilege, secure configurations
- **Declarative Configuration**: All infrastructure defined as code
- **Reusability**: Base configurations with environment-specific overlays
- **Automation**: Minimal manual operations through CI/CD integration

## Quick Start

### Prerequisites

- **kubectl** >= 1.28.0 - Kubernetes CLI
- **kustomize** >= 5.0.0 - Kubernetes configuration management
- **sops** >= 3.7.0 - Secrets encryption
- **age** >= 1.1.0 - Encryption backend for SOPS
- **Terraform** >= 1.6.0 - Infrastructure provisioning (optional)
- **Git** >= 2.40.0 - Version control

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/eda-infrastructure.git
cd eda-infrastructure

# Install kubectl (macOS)
brew install kubectl

# Install kustomize (macOS)
brew install kustomize

# Install SOPS and Age (macOS)
brew install sops age

# Install Terraform (macOS)
brew install terraform

# Verify installations
kubectl version --client
kustomize version
sops --version
age --version
terraform version
```

### Initial Setup

1. **Configure Age encryption**:

   ```bash
   # Generate Age key (if you don't have one)
   age-keygen -o ~/.config/sops/age/keys.txt

   # Get public key for .sops.yaml
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

2. **Update `.sops.yaml` with your Age public key**:

   ```bash
   # Edit argocd/.sops.yaml
   # Replace the age public key with yours
   ```

3. **Deploy an application**:

   ```bash
   # Validate configuration
   kustomize build argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos

   # Apply to cluster
   kubectl apply -k argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos

   # Verify deployment
   kubectl get pods -n edatw-cloudflared -w
   ```

## Repository Structure

```text
infrastructure/
├── argocd/              # ArgoCD application manifests
│   ├── .sops.yaml       # SOPS configuration for secrets
│   ├── edatw-cloudflared/   # Cloudflare tunnel service
│   ├── edatw-ed8/           # ED8 database service
│   └── edatw-salary-mailman/  # Salary notification service
│
├── terraform/           # Terraform configurations
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configs
│       └── cloudflared-edatw/  # Cloudflare tunnel infrastructure
│
├── docs/               # Documentation (planned)
│   ├── architecture/  # Architecture diagrams and docs
│   ├── decisions/     # Architectural Decision Records
│   ├── guides/        # How-to guides
│   └── runbooks/      # Operational procedures
│
├── AGENTS.md          # AI assistant guidance (vendor-neutral)
├── CLAUDE.md          # Claude Code-specific guidance
├── STRUCTURE.md       # Structure patterns and conventions
└── README.md          # This file
```

For complete structure documentation and patterns, see [STRUCTURE.md](STRUCTURE.md).

## Applications

### edatw-cloudflared

Cloudflare tunnel service providing secure public ingress to EDA Taiwan services.

- **Type**: DaemonSet
- **Purpose**: Public access without exposing IPs, DDoS protection
- **Technology**: Cloudflare Tunnel

```bash
kubectl apply -k argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos
```

### edatw-ed8

ED8 database service with persistent storage and automated backups.

- **Type**: StatefulSet
- **Purpose**: Primary database for EDA Taiwan applications
- **Features**: Automated backups, cronjobs, persistent volumes

```bash
kubectl apply -k argocd/edatw-ed8/overlays/shangkuei-xyz-talos
```

### edatw-salary-mailman

Automated salary notification service.

- **Type**: Deployment
- **Purpose**: Process and send salary-related notifications
- **Features**: SMTP integration, scheduled processing

```bash
kubectl apply -k argocd/edatw-salary-mailman/overlays/shangkuei-xyz-talos
```

For detailed application documentation, see [argocd/README.md](argocd/README.md).

## Common Operations

### Working with ArgoCD Applications

```bash
# Validate Kustomize configuration
kustomize build argocd/{app-name}/overlays/{cluster}

# Test with dry-run
kubectl apply --dry-run=server -k argocd/{app-name}/overlays/{cluster}

# Show diff against cluster
kubectl diff -k argocd/{app-name}/overlays/{cluster}

# Apply configuration
kubectl apply -k argocd/{app-name}/overlays/{cluster}

# Monitor deployment
kubectl get pods -n {namespace} -w
```

### Managing Secrets

```bash
# Create new encrypted secret
sops -e secret.yaml > secret.sops.yaml

# Edit existing encrypted secret
sops argocd/{app}/overlays/{cluster}/secret-{name}.sops.yaml

# View encrypted secret
sops -d secret.sops.yaml
```

### Terraform Operations

```bash
# Navigate to environment
cd terraform/environments/{env-name}

# Initialize (decrypts configs via Makefile)
make init

# Plan changes
make plan

# Apply changes
make apply

# Clean decrypted files
make clean
```

### Viewing EDA Taiwan Resources

```bash
# Get all EDA Taiwan resources
kubectl get all -A | grep edatw

# Get all EDA Taiwan namespaces
kubectl get ns | grep edatw

# Get pods across all EDA Taiwan namespaces
kubectl get pods -A | grep edatw

# View logs
kubectl logs -n {namespace} {pod-name} -f
```

## Secrets Management

All sensitive data is encrypted using **SOPS with Age encryption**:

- **Configuration**: `argocd/.sops.yaml`
- **Key Location**: `~/.config/sops/age/keys.txt`
- **Pattern**: All secrets use `.sops.yaml` suffix

### Encryption Workflow

```bash
# 1. Create unencrypted secret
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  password: "changeme"
EOF

# 2. Encrypt with SOPS
sops -e secret.yaml > secret.sops.yaml

# 3. Remove unencrypted file
rm secret.yaml

# 4. Add to ksops-generator.yaml
# 5. Reference in kustomization.yaml
```

### Security Best Practices

- **Never commit unencrypted secrets**
- **Rotate keys regularly**
- **Use principle of least privilege**
- **Audit access to secrets**
- **Use separate Age keys per environment** (recommended)

## Development Workflow

### Creating New Application

1. **Review patterns** in [STRUCTURE.md](STRUCTURE.md)
2. **Create directory structure**:

   ```bash
   mkdir -p argocd/edatw-{service}/{base,overlays/shangkuei-xyz-talos}
   ```

3. **Create base manifests**:
   - `namespace.yaml`
   - `serviceaccount.yaml`
   - `deployment.yaml` (or statefulset/daemonset)
   - `service.yaml`
   - `kustomization.yaml`

4. **Create overlay configuration**:
   - `kustomization.yaml`
   - `ksops-generator.yaml`
   - `secret-*.sops.yaml`

5. **Validate and test**:

   ```bash
   kustomize build argocd/edatw-{service}/overlays/shangkuei-xyz-talos
   kubectl apply --dry-run=server -k argocd/edatw-{service}/overlays/shangkuei-xyz-talos
   ```

6. **Update documentation**:
   - Add to [argocd/README.md](argocd/README.md)
   - Document purpose and deployment

### Updating Existing Application

1. **Read existing configuration**
2. **Make changes following patterns**
3. **Validate with kustomize build**
4. **Test with kubectl diff**
5. **Apply changes**
6. **Monitor deployment**

## Testing

### Pre-Commit Validation

```bash
# Kustomize build test
kustomize build argocd/*/overlays/*/

# Kubernetes dry-run
kubectl apply --dry-run=server -k argocd/*/overlays/*/

# Terraform validation
terraform fmt -check -recursive terraform/

# Documentation lint
markdownlint '**/*.md'

# YAML lint
yamllint argocd/
```

### Integration Testing

- Deploy to test cluster first
- Verify functionality with smoke tests
- Test rollback procedures
- Validate monitoring and alerting

## Documentation

### Key Documents

- **[STRUCTURE.md](STRUCTURE.md)**: Repository structure, patterns, and conventions
- **[AGENTS.md](AGENTS.md)**: AI assistant guidance for infrastructure work
- **[CLAUDE.md](CLAUDE.md)**: Claude Code-specific tool integration
- **[argocd/README.md](argocd/README.md)**: ArgoCD applications documentation

### Future Documentation (Planned)

- **docs/decisions/**: Architectural Decision Records (ADRs)
- **docs/architecture/**: Architecture diagrams and designs
- **docs/guides/**: Step-by-step how-to guides
- **docs/runbooks/**: Operational procedures and troubleshooting

## Contributing

1. **Read the guides**:
   - [AGENTS.md](AGENTS.md): AI assistant guidance (vendor-neutral)
   - [CLAUDE.md](CLAUDE.md): Claude Code specific guidance
   - [STRUCTURE.md](STRUCTURE.md): Structure and patterns

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/my-feature
   ```

3. **Make changes**:
   - Follow patterns in STRUCTURE.md
   - Encrypt secrets with SOPS
   - Update documentation

4. **Test locally**:

   ```bash
   kustomize build argocd/*/overlays/*/
   kubectl apply --dry-run=server -k argocd/*/overlays/*/
   markdownlint '**/*.md'
   ```

5. **Create pull request**:
   - Use conventional commits format
   - Include validation output
   - Update relevant documentation

## Troubleshooting

### Common Issues

**Kustomize build fails**:

```bash
# Check for YAML syntax errors
yamllint argocd/{app}/

# Verify all resources exist
ls -la argocd/{app}/base/
ls -la argocd/{app}/overlays/{cluster}/
```

**SOPS decryption fails**:

```bash
# Verify Age key exists
cat ~/.config/sops/age/keys.txt

# Check .sops.yaml configuration
cat argocd/.sops.yaml

# Test decryption manually
sops -d argocd/{app}/overlays/{cluster}/secret-*.sops.yaml
```

**kubectl apply fails**:

```bash
# Use dry-run to see errors
kubectl apply --dry-run=server -k argocd/{app}/overlays/{cluster}

# Check cluster connectivity
kubectl cluster-info

# Verify namespace exists
kubectl get ns {namespace}
```

### Getting Help

- Review [STRUCTURE.md](STRUCTURE.md) for patterns
- Check [argocd/README.md](argocd/README.md) for application-specific docs
- Consult [AGENTS.md](AGENTS.md) for workflows and best practices

## Git Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `refactor`, `chore`
**Scopes**: `argocd`, `terraform`, `docs`, `ci`

**Examples**:

```bash
feat(argocd): add edatw-monitoring application
fix(terraform): correct cloudflared tunnel configuration
docs(structure): update ArgoCD application patterns
```

## References

- **Internal Documentation**:
  - [STRUCTURE.md](STRUCTURE.md) - Structure and patterns
  - [AGENTS.md](AGENTS.md) - AI assistant guidance
  - [argocd/README.md](argocd/README.md) - Application documentation

- **External Resources**:
  - [Kustomize Documentation](https://kustomize.io/)
  - [SOPS Documentation](https://github.com/mozilla/sops)
  - [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
  - [Terraform Documentation](https://www.terraform.io/docs)
  - [Conventional Commits](https://www.conventionalcommits.org/)

---

**Maintained by**: EDA Taiwan Infrastructure Team
