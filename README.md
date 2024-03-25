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

### Fixed IPs

| Name              | IPs                               |
| ----------------- | --------------------------------- |
| DNS / DHCP        | `192.168.42.10`                   |
| Proxmox           | `192.168.42.11`              |
| Kube Endpoint VIP | `192.168.42.42`                   |
| Kube LB Range     | `192.168.42.50 - 192.168.42.60`   |
| DHCP Range        | `192.168.42.100 - 192.168.42.250` |

## Bootstrapping k8s

### Prepare nodes

```bash
# generate talos config
ansible-playbook ./playbooks/kube.yaml
```

```bash
# apply config to the control plane
# --insecure required only for the initial config apply
talosctl apply-config -e k8s-server-1.lan -n k8s-server-1.lan --file=./talos/k8s-server-1.yaml --insecure
```

```bash
# bootstrap etcd (only needed to run on one node)
talosctl bootstrap -e k8s-server-1 -n k8s-server-1
```

```bash
# repeat applying config to reset of the nodes
# --insecure required only for the initial config apply
talosctl apply-config -n k8s-worker-1 --file=./talos/k8s-worker-1.yaml --insecure
talosctl apply-config -n k8s-worker-2 --file=./talos/k8s-worker-2.yaml --insecure
```

### Install Flux

```bash
# Run pre-installation checks
flux check --pre
```

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

## System extensions

System extensions can only be installed on install or upgrade. To install extensions on an existing node:

```bash
talosctl -e <endpoint ip/hostname> -n <node ip/hostname> upgrade --image=ghcr.io/siderolabs/installer:<talos version>

# Check status
talosctl -e <endpoint ip/hostname> -n <node ip/hostname> get extensions
```

# Thanks

A lot of the setup here was inspired by folks who share their [home Kubernetes setup](https://github.com/topics/k8s-at-home).
