# Flux GitOps Setup

## Overview

This cluster uses [Flux v2](https://fluxcd.io/) for GitOps continuous delivery. Flux automatically reconciles the cluster state with the manifests in this repository.

## Architecture

```
cluster/
├── bootstrap/                    # Initial Flux installation
│   ├── kustomization.yaml       # Flux controllers from GitHub
│   ├── helmfile.d/              # Cilium CNI bootstrap
│   ├── age-key.sops.yaml        # SOPS encryption key
│   └── github-deploy-key.sops.yaml
├── flux/
│   ├── config/
│   │   ├── flux.yaml            # Self-managed Flux via OCI
│   │   ├── cluster.yaml         # GitRepository + root Kustomization
│   │   └── kustomization.yaml
│   ├── repositories/
│   │   └── helm/                # HelmRepository sources
│   ├── vars/
│   │   └── cluster-secrets.sops.yaml  # Cluster-wide variables
│   └── apps.yaml                # Root application Kustomization
└── apps/                        # Application manifests by namespace
    ├── cert-manager/
    ├── default/
    ├── kube-system/
    ├── media/
    ├── monitoring/
    ├── networking/
    └── storage/
```

## Components

### Source Controller

Manages Git repositories, Helm repositories, and OCI artifacts.

**Git Source:**

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: home-cluster
  namespace: flux-system
spec:
  interval: 30m
  url: ssh://git@github.com/davidharrigan/home-ops
  ref:
    branch: main
  secretRef:
    name: github-deploy-key
```

**OCI Source (for self-managed Flux):**

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: flux-manifests
  namespace: flux-system
spec:
  interval: 10m
  url: oci://ghcr.io/fluxcd/flux-manifests
  ref:
    tag: v2.7.5
```

### Kustomize Controller

Reconciles Kustomization resources, applying manifests from Git.

**Root Kustomization:**

- Path: `./cluster/flux`
- Features: SOPS decryption, variable substitution
- Interval: 30 minutes

**Apps Kustomization:**

- Path: `./cluster/apps`
- Auto-patches child Kustomizations with SOPS and substitution
- Uses label selector for opt-out: `substitution.flux.home.arpa/disabled notin (true)`

### Helm Controller

Manages HelmRelease resources with these performance optimizations:

- **Concurrent reconciliations:** 8
- **API rate limits:** QPS=500, Burst=1000
- **Drift detection:** Enabled by default (v2.7+)
- **OOM protection:** Enabled at 95% memory threshold
- **Debug logging:** Enabled

### Notification Controller

Handles alerts and webhooks

## Secret Management

### SOPS Integration

Secrets are encrypted using SOPS with Age encryption:

```yaml
spec:
  decryption:
    provider: sops
    secretRef:
      name: age-key
```

The Age key is stored at `~/.config/sops/age/home-ops.txt`.

### Variable Substitution

Cluster-wide variables are stored in `cluster/flux/vars/cluster-secrets.sops.yaml`:

```yaml
postBuild:
  substituteFrom:
    - kind: Secret
      name: cluster-secrets
```

Variables are referenced in manifests as `${SECRET_DOMAIN}`, `${SECRET_ACME_EMAIL}`, etc.

## Helm Repositories

Located in `cluster/flux/repositories/helm/`:

## Application Pattern

Applications follow a two-level Kustomization structure:

### Level 1: Namespace Kustomization

`cluster/apps/<namespace>/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./namespace.yaml
  - ./app-name/ks.yaml
```

### Level 2: Application Kustomization

`cluster/apps/<namespace>/<app>/ks.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-apps-<app>
  namespace: flux-system
spec:
  path: ./cluster/apps/<namespace>/<app>/app
  sourceRef:
    kind: GitRepository
    name: home-cluster
  dependsOn:
    - name: cluster-apps-<dependency>
  interval: 30m
  prune: true
  wait: true
```

### Level 3: Application Resources

`cluster/apps/<namespace>/<app>/app/`:

```
app/
├── kustomization.yaml
├── helmrelease.yaml
└── secret.sops.yaml (optional)
```

## Dependency Management

Use `dependsOn` to ensure ordering:

```yaml
# Example: nginx depends on cert-manager-issuers
spec:
  dependsOn:
    - name: cluster-apps-cert-manager-issuers
```

Common dependency chains:

- `cert-manager` → `cert-manager-issuers` → ingress controllers
- `external-dns` → `cloudflared`

## Bootstrap Process

### Fresh Cluster

```bash
# Full bootstrap
just bootstrap bootstrap

# Or step by step:
just bootstrap talos-apply
just bootstrap talos-bootstrap
just bootstrap kubeconfig
just bootstrap wait-nodes
just bootstrap helmfile-sync    # Installs Cilium
just bootstrap flux-install     # Installs Flux controllers
just bootstrap flux-secrets     # Applies SOPS keys
just bootstrap flux-config      # Starts reconciliation
```

### Manual Bootstrap

```bash
# Install Flux controllers
kubectl apply --server-side --kustomize ./cluster/bootstrap

# Apply SOPS keys
sops --decrypt ./cluster/bootstrap/age-key.sops.yaml | kubectl apply -f -
sops --decrypt ./cluster/bootstrap/github-deploy-key.sops.yaml | kubectl apply -f -

# Start reconciliation
kubectl apply --server-side --kustomize ./cluster/flux/config

# Verify
flux check
```

## Upgrade Process

### Pre-Upgrade Checklist

1. **Check current version:**

   ```bash
   flux version
   ```

2. **Review release notes:**

   - https://github.com/fluxcd/flux2/releases
   - Check for API deprecations and breaking changes

3. **Backup current state:**
   ```bash
   kubectl get all -n flux-system -o yaml > flux-backup.yaml
   ```

### Upgrade Steps

#### Step 1: Migrate Manifests

If upgrading across major API changes, migrate local manifests first:

```bash
# Migrate to target version's APIs
flux migrate -v <target-version> -f ./cluster

# Review changes
git diff

# Commit if changes were made
git add -A
git commit -m "chore: migrate Flux manifests to v<version> APIs"
git push
```

#### Step 2: Update Version Pins

Edit these files:

**`cluster/bootstrap/kustomization.yaml`:**

```yaml
resources:
  - github.com/fluxcd/flux2/manifests/install?ref=v<version>
```

**`cluster/flux/config/flux.yaml`:**

```yaml
spec:
  ref:
    tag: v<version>
```

#### Step 3: Apply Upgrade

**For existing cluster:**

```bash
# Apply updated Flux controllers
kubectl apply --server-side --kustomize ./cluster/bootstrap

# Apply updated config (triggers self-update via OCI)
kubectl apply --server-side --kustomize ./cluster/flux/config

# Migrate in-cluster resources if needed
flux migrate

# Verify
flux check
flux reconcile source git home-cluster
```

#### Step 4: Verify

```bash
# Check all controllers are running
flux check

# Verify reconciliation
flux get sources git
flux get kustomizations
flux get helmreleases -A

# Check for errors
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Rollback

If issues occur:

```bash
# Revert version pins in Git
git revert HEAD
git push

# Force reconcile
flux reconcile source git home-cluster --with-source
flux reconcile kustomization flux --with-source
```

## Troubleshooting

### View Controller Logs

```bash
# All controllers
kubectl logs -n flux-system -l app.kubernetes.io/part-of=flux --tail=100

# Specific controller
kubectl logs -n flux-system deploy/kustomize-controller --tail=100
kubectl logs -n flux-system deploy/helm-controller --tail=100
kubectl logs -n flux-system deploy/source-controller --tail=100
```

### Force Reconciliation

```bash
# Git source
flux reconcile source git home-cluster

# All kustomizations
flux reconcile kustomization cluster --with-source
flux reconcile kustomization cluster-apps --with-source

# Specific helm release
flux reconcile helmrelease <name> -n <namespace>
```

### Suspend/Resume

```bash
# Suspend all reconciliation (maintenance)
flux suspend kustomization --all

# Resume
flux resume kustomization --all

# Suspend specific resource
flux suspend helmrelease <name> -n <namespace>
```

### Common Issues

**Kustomization stuck in "reconciling":**

```bash
# Check for dependency issues
flux get kustomizations

# Check events
kubectl describe kustomization <name> -n flux-system
```

**HelmRelease failing:**

```bash
# Get detailed status
flux get helmrelease <name> -n <namespace>

# Check Helm history
helm history <name> -n <namespace>

# Force upgrade
flux reconcile helmrelease <name> -n <namespace> --force
```

## References

- [Flux Documentation](https://fluxcd.io/flux/)
- [Flux GitHub](https://github.com/fluxcd/flux2)
- [API Reference](https://fluxcd.io/flux/components/)
- [Upgrade Procedure for v2.7+](https://github.com/fluxcd/flux2/discussions/5572)
