## Getting Started

### Dependencies

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)
- [helmfile](https://helmfile.readthedocs.io/)
- [just](https://github.com/casey/just)
- [age](https://github.com/FiloSottile/age)
- [sops](https://github.com/getsops/sops)
- [direnv](https://github.com/direnv/direnv)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [talosctl](https://www.talos.dev/latest/introduction/quickstart/)
- [flux](https://fluxcd.io/flux/installation/)

### Setup

#### Install pre-commit hooks

```bash
pre-commit install --install-hooks
pre-commit run --all-files
```

#### Setup Age

If generating a new keypair, all `*.sops.*` files will need to be re-created.

```bash
# Create age key pair
age-keygen -o age.agekey
```

```bash
# Move generated key
mkdir -p ~/.config/sops/age
mv age.agekey ~/.config/sops/age/home-ops.txt
```

#### Direnv

```bash
# allow .envrc to be loaded by direnv
direnv allow .
```

## Bootstrapping k8s

### Quick Start

```bash
just bootstrap bootstrap
```

This runs all stages in sequence:

1. Generate and apply Talos configs to all nodes
2. Bootstrap etcd on the first control plane
3. Fetch kubeconfig
4. Wait for Kubernetes API
5. Install Cilium via helmfile
6. Install Flux and apply secrets
7. Start Flux reconciliation

### Manual Bootstrap

If you need more control, run individual stages:

```bash
# Generate Talos configurations
just talos gen-config

# Apply configs to nodes
just bootstrap nodes

# Bootstrap etcd
just bootstrap etcd

# Configure talosctl endpoints
just bootstrap talosconfig

# Get kubeconfig
just bootstrap kubeconfig

# Wait for nodes
just bootstrap wait

# Install Cilium
just bootstrap cilium

# Install Flux
just bootstrap flux
just bootstrap flux-secrets
just bootstrap flux-config
```

### Verify

```bash
# Check Flux status
flux check

# Check all resources
kubectl get hr -A  # Helm releases
kubectl get ks -A  # Kustomizations
```

## Talos Operations

```bash
# Show cluster info
just talos info

# Generate machine configs
just talos genconfig

# Generate custom installer image URL
just talos genimage

# Clean generated configs
just talos clean
```

## System extensions

System extensions can only be installed on install or upgrade:

```bash
talosctl -e <endpoint> -n <node> upgrade --image=ghcr.io/siderolabs/installer:<talos version>

# Check status
talosctl -e <endpoint> -n <node> get extensions
```

## Thanks

A lot of the setup here was inspired by folks who share their [home Kubernetes setup](https://github.com/topics/k8s-at-home).
