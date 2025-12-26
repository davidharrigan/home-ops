# Cilium CNI Setup

## Overview

This cluster uses [Cilium](https://cilium.io/) as the Container Network Interface (CNI) plugin, providing eBPF-based networking, security, and observability. Cilium replaces kube-proxy and provides native load balancing with L2 announcements for bare-metal deployments.

## Architecture

```
cluster/
├── bootstrap/
│   └── helmfile.d/
│       └── 00-cilium.yaml         # Bootstrap installation via helmfile
└── apps/
    └── kube-system/
        └── cilium/
            ├── ks.yaml            # Flux Kustomization
            └── app/
                ├── kustomization.yaml
                ├── helmrelease.yaml         # Flux HelmRelease
                ├── cilium-base-values.yaml  # Core CNI configuration
                ├── cilium-hubble-values.yaml # Observability config
                ├── lb-pool.yaml             # LoadBalancer IP pool
                └── l2-policy.yaml           # L2 announcement policy
```

### Two-Phase Installation

1. **Bootstrap Phase**: Cilium is installed via helmfile before Flux, since a CNI is required for cluster networking
2. **GitOps Phase**: Flux takes over management using the HelmRelease, enabling Hubble observability features

## Configuration

### Base Configuration (`cilium-base-values.yaml`)

Core CNI settings used by both bootstrap and Flux:

| Setting | Value | Description |
|---------|-------|-------------|
| `kubeProxyReplacement` | `true` | Full kube-proxy replacement |
| `routingMode` | `native` | Native routing (no encapsulation) |
| `ipam.mode` | `kubernetes` | Use Kubernetes IPAM |
| `loadBalancer.mode` | `dsr` | Direct Server Return for LB |
| `loadBalancer.algorithm` | `maglev` | Consistent hashing algorithm |
| `l2announcements.enabled` | `true` | ARP announcements for LB IPs |
| `bandwidthManager.enabled` | `true` | eBPF bandwidth management |
| `bpf.masquerade` | `true` | eBPF-based masquerading |
| `endpointRoutes.enabled` | `true` | Per-endpoint routing |

**Talos-specific settings:**

```yaml
k8sServiceHost: localhost
k8sServicePort: 7445
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup
```

### Hubble Configuration (`cilium-hubble-values.yaml`)

Observability features enabled via Flux (not during bootstrap):

- **Hubble Metrics**: DNS, TCP, flow, HTTP, ICMP, port-distribution
- **Hubble Relay**: Aggregates flow data from agents
- **Hubble UI**: Web interface for flow visualization
- **Prometheus Integration**: ServiceMonitors for all components
- **Grafana Dashboards**: Auto-provisioned to `Cilium` folder

### Load Balancer IP Pool (`lb-pool.yaml`)

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: lb-pool
spec:
  allowFirstLastIPs: "Yes"
  blocks:
    - start: 192.168.42.50
      stop: 192.168.42.99
```

### L2 Announcement Policy (`l2-policy.yaml`)

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: l2-policy
spec:
  loadBalancerIPs: true
  interfaces:
    - "^enp.*"
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
```

## Bootstrap Process

### Fresh Cluster Installation

```bash
# Full bootstrap (includes Cilium)
just bootstrap bootstrap

# Or install Cilium only
just bootstrap cilium
```

The bootstrap uses helmfile to install Cilium with base values:

```bash
cd cluster/bootstrap
helmfile -f helmfile.d/ sync
```

### What Bootstrap Does

1. Installs Cilium chart from `oci://quay.io/cilium/cilium`
2. Waits for Cilium CRDs to be available
3. Applies `CiliumLoadBalancerIPPool` for LoadBalancer IP allocation
4. Applies `CiliumL2AnnouncementPolicy` for ARP announcements
5. Waits for Cilium DaemonSet rollout

### Verifying Installation

```bash
# Check Cilium pods
kubectl -n kube-system get pods -l k8s-app=cilium

# Check Cilium status
kubectl -n kube-system exec ds/cilium -- cilium status

# Verify connectivity
kubectl -n kube-system exec ds/cilium -- cilium connectivity test
```

## Upgrade Process

### Pre-Upgrade Checklist

1. **Check current version:**

   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium version
   helm -n kube-system list | grep cilium
   ```

2. **Review release notes:**

   - https://github.com/cilium/cilium/releases
   - https://docs.cilium.io/en/stable/operations/upgrade/

3. **Check kernel requirements:**

   Cilium 1.18+ requires Linux kernel v5.10 or newer.

   ```bash
   kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.status.nodeInfo.kernelVersion}{"\n"}{end}'
   ```

### Upgrade Steps

#### Step 1: Update Version Pins

Edit these files with the new version:

**`cluster/bootstrap/helmfile.d/00-cilium.yaml`:**

```yaml
releases:
  - name: cilium
    version: 1.18.5  # Update this
```

**`cluster/apps/kube-system/cilium/app/helmrelease.yaml`:**

```yaml
spec:
  chart:
    spec:
      version: 1.18.5  # Update this
```

#### Step 2: Review Configuration Changes

Check for breaking changes in helm values between versions:

```bash
# Compare default values
helm show values cilium/cilium --version <old> > old-values.yaml
helm show values cilium/cilium --version <new> > new-values.yaml
diff old-values.yaml new-values.yaml
```

#### Step 3: Apply Upgrade

**For running cluster (Flux-managed):**

```bash
# Commit and push changes
git add -A
git commit -m "feat: upgrade cilium to v1.18.5"
git push

# Force reconciliation
flux reconcile helmrelease cilium -n kube-system

# Monitor rollout
kubectl -n kube-system rollout status daemonset/cilium
```

**For bootstrap-only upgrade:**

```bash
cd cluster/bootstrap
helmfile -f helmfile.d/ sync
```

#### Step 4: Verify

```bash
# Check version
kubectl -n kube-system exec ds/cilium -- cilium version

# Verify status
kubectl -n kube-system exec ds/cilium -- cilium status

# Check for errors
kubectl -n kube-system logs -l k8s-app=cilium --tail=100 | grep -i error
```

### Major Version Upgrade Notes

#### 1.15.x to 1.18.x

Key changes:

- **Kernel requirement**: v5.10 or newer required
- **kubeProxyReplacement**: Individual feature flags deprecated; use `kubeProxyReplacement: true`
- **L2 announcements**: `l2NeighDiscovery.enabled` now defaults to `false`
- **BGP CRDs**: Migrate from `v2alpha1` to `v2` API versions if using BGP

For running clusters, add `upgradeCompatibility` to minimize datapath disruption:

```yaml
# helmrelease.yaml - add during upgrade, remove after
upgradeCompatibility: "1.15"
```

### Rollback

If issues occur:

```bash
# Revert changes in Git
git revert HEAD
git push

# Force reconcile
flux reconcile helmrelease cilium -n kube-system --force

# Or manually rollback
helm -n kube-system rollback cilium
```

## Troubleshooting

### View Cilium Logs

```bash
# Agent logs
kubectl -n kube-system logs -l k8s-app=cilium --tail=100

# Operator logs
kubectl -n kube-system logs -l name=cilium-operator --tail=100

# Specific pod
kubectl -n kube-system logs cilium-xxxxx -c cilium-agent
```

### Cilium CLI Commands

```bash
# Status
kubectl -n kube-system exec ds/cilium -- cilium status

# Endpoint list
kubectl -n kube-system exec ds/cilium -- cilium endpoint list

# Service list
kubectl -n kube-system exec ds/cilium -- cilium service list

# BPF maps
kubectl -n kube-system exec ds/cilium -- cilium bpf lb list
kubectl -n kube-system exec ds/cilium -- cilium bpf ct list global
```

### Load Balancer Issues

```bash
# Check IP pool status
kubectl get ciliumloadbalancerippools

# Check L2 announcements
kubectl get ciliuml2announcementpolicies

# Debug LB allocation
kubectl -n kube-system exec ds/cilium -- cilium bpf lb list
```

### Connectivity Issues

```bash
# Run connectivity test
kubectl -n kube-system exec ds/cilium -- cilium connectivity test

# Check node connectivity
kubectl -n kube-system exec ds/cilium -- cilium node list

# Check identity allocation
kubectl get ciliumidentities
```

### Common Issues

**Pods stuck in ContainerCreating:**

```bash
# Check CNI logs
journalctl -u kubelet | grep -i cni

# Verify Cilium is running on the node
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

**LoadBalancer services not getting IPs:**

```bash
# Check IP pool has available IPs
kubectl describe ciliumloadbalancerippools lb-pool

# Verify L2 policy matches interfaces
ip link show | grep enp
kubectl get ciliuml2announcementpolicies -o yaml
```

**Hubble not collecting flows:**

```bash
# Check Hubble is enabled
kubectl -n kube-system exec ds/cilium -- cilium status | grep Hubble

# Verify relay is running
kubectl -n kube-system get pods -l k8s-app=hubble-relay
```

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium GitHub](https://github.com/cilium/cilium)
- [Helm Chart Values](https://github.com/cilium/cilium/blob/main/install/kubernetes/cilium/values.yaml)
- [Upgrade Guide](https://docs.cilium.io/en/stable/operations/upgrade/)
- [Talos + Cilium Guide](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium)
