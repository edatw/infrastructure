# ArgoCD Applications for EDA Taiwan

This directory contains ArgoCD application manifests for EDA Taiwan services, managed using Kustomize and SOPS-encrypted secrets.

## Overview

All applications follow a **base + overlays** pattern with KSOPS integration for encrypted secrets management:

- **Base**: Reusable Kubernetes manifests (deployments, services, namespaces)
- **Overlays**: Cluster-specific configurations with encrypted secrets

## Applications

### edatw-cloudflared

Cloudflare tunnel service providing public ingress to EDA Taiwan services.

- **Type**: DaemonSet
- **Purpose**: Secure ingress without exposing public IPs
- **Secrets**: Tunnel credentials and certificates

**Structure**:

```text
edatw-cloudflared/
├── base/
│   ├── daemonset.yaml
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   └── kustomization.yaml
└── overlays/
    └── shangkuei-xyz-talos/
        ├── kustomization.yaml
        ├── ksops-generator.yaml
        └── secret-cloudflared.yaml
```

**Deploy**:

```bash
kubectl apply -k argocd/edatw-cloudflared/overlays/shangkuei-xyz-talos
```

### edatw-ed8

ED8 database service with persistent storage and automated backups.

- **Type**: StatefulSet
- **Purpose**: Primary database for EDA Taiwan applications
- **Features**: Automated backups, cronjobs for maintenance, persistent volumes
- **Secrets**: Database credentials, API keys, CLI configurations

**Structure**:

```text
edatw-ed8/
├── base/
│   ├── configs/                    # ConfigMaps
│   │   ├── backup.cnf
│   │   ├── default.cnf
│   │   ├── ed8-database.cnf
│   │   └── innodb.cnf
│   ├── scripts/                    # Lifecycle scripts
│   │   ├── exit.sh
│   │   ├── logical-backup.sh
│   │   ├── physical-backup.sh
│   │   ├── restore-entrypoint.sh
│   │   └── restore-logical-backup.sh
│   ├── cronjob-backup.yaml
│   ├── cronjob-notify.yaml
│   ├── cronjob-probes.yaml
│   ├── namespace.yaml
│   ├── persistent-volume-claim-*.yaml
│   ├── service-account-ed8.yaml
│   ├── statefulset-ed8.yaml
│   └── kustomization.yaml
└── overlays/
    └── shangkuei-xyz-talos/
        ├── persistent-volume-*.yaml
        ├── secret-ed8-*.sops.yaml
        ├── storage-class-*.yaml
        ├── ksops-generator.yaml
        └── kustomization.yaml
```

**Deploy**:

```bash
kubectl apply -k argocd/edatw-ed8/overlays/shangkuei-xyz-talos
```

### edatw-salary-mailman

Salary mailman service for automated employee notifications.

- **Type**: Deployment
- **Purpose**: Process and send salary-related notifications
- **Secrets**: SMTP credentials, API keys, registry pull secrets

**Structure**:

```text
edatw-salary-mailman/
├── base/
│   ├── deployment.yaml
│   ├── namespace.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── kustomization.yaml
├── overlays/
│   └── shangkuei-xyz-talos/
│       ├── kustomization.yaml
│       ├── ksops-generator.yaml
│       └── secret-ghcr-pull.yaml
├── MIGRATION.md
└── README.md
```

**Deploy**:

```bash
kubectl apply -k argocd/edatw-salary-mailman/overlays/shangkuei-xyz-talos
```

## Naming Convention

Pattern: `edatw-{service-name}`

- `edatw`: Organization prefix (EDA Taiwan)
- `{service-name}`: Descriptive service identifier

**Benefits**:

- Clear ownership identification
- Namespace collision prevention
- Easy filtering: `kubectl get all -A | grep edatw`
- Consistent across environments

## Directory Structure Pattern

All applications follow this standard structure:

```text
{app-name}/
├── base/                           # Reusable base configuration
│   ├── namespace.yaml              # Namespace definition
│   ├── serviceaccount.yaml         # Service account
│   ├── deployment.yaml             # Workload (deployment/statefulset/daemonset)
│   ├── service.yaml                # Service definition (if needed)
│   ├── configmap.yaml              # ConfigMaps (if needed)
│   └── kustomization.yaml          # Base kustomization
│
└── overlays/                       # Environment-specific configs
    └── {cluster-name}/             # e.g., shangkuei-xyz-talos
        ├── kustomization.yaml      # Overlay kustomization
        ├── ksops-generator.yaml    # KSOPS secret generator
        ├── secret-*.sops.yaml      # SOPS-encrypted secrets
        ├── persistent-volume-*.yaml # Storage resources (if needed)
        └── storage-class-*.yaml    # Storage classes (if needed)
```

## Secrets Management

### SOPS Configuration

All secrets are encrypted using **SOPS with Age encryption**:

- **Config**: `argocd/.sops.yaml`
- **Key Location**: `~/.config/sops/age/keys.txt`
- **Pattern**: All secret files use `.sops.yaml` suffix

### Creating New Secret

```bash
# 1. Create unencrypted secret
cat > secret-myapp.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
  namespace: myapp
type: Opaque
stringData:
  password: "changeme"
  api-key: "secret"
EOF

# 2. Encrypt with SOPS
sops -e secret-myapp.yaml > secret-myapp.sops.yaml

# 3. Remove unencrypted file
rm secret-myapp.yaml

# 4. Add to ksops-generator.yaml
cat > ksops-generator.yaml <<EOF
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secret-generator
files:
  - secret-myapp.sops.yaml
EOF

# 5. Reference in kustomization.yaml
cat >> kustomization.yaml <<EOF
generators:
  - ksops-generator.yaml
EOF
```

### Editing Existing Secret

```bash
# Edit encrypted secret in place
sops argocd/edatw-myapp/overlays/shangkuei-xyz-talos/secret-myapp.sops.yaml

# SOPS will decrypt, open editor, and re-encrypt on save
```

### KSOPS Generator Pattern

Every overlay with secrets needs a `ksops-generator.yaml`:

```yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secret-generator
files:
  - secret-app1.sops.yaml
  - secret-app2.sops.yaml
```

Referenced in `kustomization.yaml`:

```yaml
generators:
  - ksops-generator.yaml
```

## Kustomize Workflows

### Validating Configuration

```bash
# Build kustomization (test locally)
kustomize build argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Dry-run apply (test with cluster API)
kubectl apply --dry-run=server -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Show diff against cluster
kubectl diff -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos
```

### Deploying Application

```bash
# Apply configuration
kubectl apply -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Watch deployment progress
kubectl get pods -n myapp -w

# Check logs
kubectl logs -n myapp deployment/myapp -f
```

### Troubleshooting

```bash
# Describe resources
kubectl describe -k argocd/edatw-myapp/overlays/shangkuei-xyz-talos

# Get events
kubectl get events -n myapp --sort-by='.lastTimestamp'

# Check secrets (verify they were created)
kubectl get secrets -n myapp

# Verify SOPS decryption worked
kubectl get secret myapp-secret -n myapp -o yaml
```

## Creating New Application

Follow these steps when creating a new ArgoCD application:

### 1. Create Directory Structure

```bash
mkdir -p argocd/edatw-{service}/{base,overlays/shangkuei-xyz-talos}
```

### 2. Create Base Manifests

Create in `base/` directory:

- `namespace.yaml` - Define namespace
- `serviceaccount.yaml` - Service account for RBAC
- `deployment.yaml` - Main workload (or statefulset/daemonset)
- `service.yaml` - Service definition (if needed)
- `kustomization.yaml` - List all resources

### 3. Create Overlay Manifests

Create in `overlays/shangkuei-xyz-talos/`:

- `kustomization.yaml` - Reference base and generators
- `ksops-generator.yaml` - List encrypted secret files
- `secret-{name}.sops.yaml` - Encrypted secrets

### 4. Validate and Test

```bash
# Validate Kustomize build
kustomize build argocd/edatw-{service}/overlays/shangkuei-xyz-talos

# Test with kubectl dry-run
kubectl apply --dry-run=server -k argocd/edatw-{service}/overlays/shangkuei-xyz-talos
```

### 5. Update Documentation

- Add application to this README.md
- Document purpose, type, and secrets
- Include deploy command

## Best Practices

### Resource Management

1. **Always define resource requests and limits**:

   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
     limits:
       cpu: 500m
       memory: 512Mi
   ```

2. **Use appropriate restart policies**
3. **Define liveness and readiness probes**
4. **Set proper security contexts**

### Secrets

1. **Never commit unencrypted secrets**
2. **Use SOPS for all sensitive data**
3. **Rotate secrets regularly**
4. **Use minimal required permissions**

### Naming

1. **Follow `edatw-{service}` pattern**
2. **Use descriptive resource names**
3. **Include namespace in all resources**
4. **Use consistent label selectors**

### Configuration

1. **Keep base/ generic and reusable**
2. **Put environment-specific config in overlays/**
3. **Use ConfigMaps for non-sensitive config**
4. **Document all configuration options**

## Common Operations

### View All EDA Taiwan Applications

```bash
# Get all resources
kubectl get all -A | grep edatw

# Get all namespaces
kubectl get ns | grep edatw

# Get all deployments
kubectl get deploy -A | grep edatw

# Get all statefulsets
kubectl get sts -A | grep edatw
```

### Scale Application

```bash
# Scale deployment
kubectl scale deployment -n {namespace} {deployment} --replicas=3

# Scale via kustomization
# Add to overlays/*/kustomization.yaml:
replicas:
  - name: {deployment}
    count: 3
```

### Update Application

```bash
# 1. Edit manifests
# 2. Validate changes
kustomize build argocd/edatw-{service}/overlays/shangkuei-xyz-talos

# 3. Apply changes
kubectl apply -k argocd/edatw-{service}/overlays/shangkuei-xyz-talos

# 4. Monitor rollout
kubectl rollout status deployment/{name} -n {namespace}
```

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/{name} -n {namespace}

# Rollback to previous version
kubectl rollout undo deployment/{name} -n {namespace}

# Rollback to specific revision
kubectl rollout undo deployment/{name} -n {namespace} --to-revision=2
```

## Security Considerations

### RBAC

- Each application uses dedicated ServiceAccount
- Minimal permissions granted via Roles/RoleBindings
- No cluster-wide permissions unless absolutely necessary

### Network Policies

- Define ingress/egress rules per application
- Deny all by default, allow specific traffic
- Document allowed connections

### Pod Security

- Use security contexts to drop capabilities
- Run as non-root user when possible
- Use read-only root filesystem where applicable
- Enable AppArmor/SELinux profiles

## References

- [STRUCTURE.md](../STRUCTURE.md) - Repository structure and patterns
- [AGENTS.md](../AGENTS.md) - AI assistant guidance
- [Kustomize Documentation](https://kustomize.io/)
- [SOPS Documentation](https://github.com/mozilla/sops)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
