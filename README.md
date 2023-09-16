## Getting Started

### Dependencies

- [ansible](https://www.ansible.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)
- [age](https://github.com/FiloSottile/age)
- [direnv](https://github.com/direnv/direnv)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [talosctl](https://www.talos.dev/latest/introduction/quickstart/)

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

## Networking

| Name                | CIDR              |
| ------------------- | ----------------- |
| Management          | `192.168.10.0/24` |
| Users               | `192.168.20.0/24` |
| Servers             | `192.168.42.0/24` |
| IoT                 | `192.168.50.0/24` |
| Kubernetes pods     | `10.244.0.0/16`   |
| Kubernetes services | `10.96.0.0/16`    |

### Servers VLAN

#### Fixed IPs

| Name              | IPs                               |
| ----------------- | --------------------------------- |
| DNS / DHCP        | `192.168.42.10`                   |
| Kube Endpoint VIP | `192.168.42.42`                   |
| Kube LB Range     | `192.168.42.50 - 192.168.42.60`   |
| DHCP Range        | `192.168.42.100 - 192.168.42.250` |

## Bootstrapping k8s

```bash
# Run pre-installation checks
flux check --pre
```

### Install Flux

```bash
kubectl apply --server-side --kustomize ./cluster/bootstrap
```

### Apply configuration

```bash
sops --decrypt ./cluster/bootstrap/age-key.sops.yaml | kubectl apply -f -
sops --decrypt ./cluster/bootstrap/github-deploy-key.sops.yaml | kubectl apply -f -
sops --decrypt ./cluster/flux/vars/cluster-secrets.sops.yaml | kubectl apply -f -
```

### Kickoff Flux

```bash
kubectl apply --server-side --kustomize ./cluster/flux/config
```

### Verify

```bash
# Run post-installation checks
flux check
```

### Verify

```bash
# Run post-installation checks
flux check
```
