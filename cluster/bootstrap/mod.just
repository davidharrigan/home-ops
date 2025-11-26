# Bootstrap module
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

# Directories
root_dir := justfile_dir()
bootstrap_dir := root_dir / "cluster/bootstrap"
talos_dir := root_dir / "cluster/talos"
machines_dir := talos_dir / "machines"
flux_dir := root_dir / "cluster/flux"




[private]
target-nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    for m in ${TALOS_CONFIG_DIR}/*.yaml; do
        hostname=$(yq eval '.machine.network.hostname' "$m")
        echo ${hostname}.lan
    done

# Get first control plane node hostname
[private]
controlplane-node:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r node; do
        just talos is-controller "${node%.lan}" && echo "${node}" && break
    done < <(just bootstrap target-nodes)

# Talos config values
[private]
default: nodes etcd talosconfig kubeconfig wait cilium flux flux-secrets flux-config

[doc('Apply Talos configuration to all nodes')]
nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r node; do
        just talos apply "${node}" --insecure --force
        echo "Applying Talos config to ${node}..."
    done < <(just bootstrap target-nodes)

[doc('Bootstrap Kubernetes etcd (idempotent)')]
etcd:
    #!/usr/bin/env bash
    set -euo pipefail
    node=$(just bootstrap controlplane-node)

    # Check if already bootstrapped
    if talosctl etcd members -n "$node" &>/dev/null; then
        just log info "etcd already bootstrapped, skipping"
        exit 0
    fi

    # Bootstrap and wait for completion
    just log info "Bootstrapping etcd on $node..."
    until op=$(talosctl bootstrap -n "$node" 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "Kubernetes bootstrap in progress. Retrying in 5s..."
        sleep 5
    done

talosconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    nodes=""
    endpoints=""
    while IFS= read -r node; do
        just talos is-controller "${node%.lan}" && endpoints="${endpoints:+$endpoints,}${node}"
        nodes="${nodes:+$nodes,}${node}"
    done < <(just bootstrap target-nodes)

    talosctl config endpoint "$endpoints"
    talosctl config nodes "$nodes"

kubeconfig path='-':
    talosctl kubeconfig {{ path }}
    just log "kubeconfig written"

[doc('Wait for Kubernetes API to be available')]
wait:
    gum spin --title "Waiting for nodes..." -- kubectl wait nodes --all --for=condition=Ready --timeout=300s

[doc('Install Cilium via helmfile')]
cilium:
    #!/usr/bin/env bash
    just log "Installing Cilium..."
    cd {{ bootstrap_dir }}
    helmfile -f helmfile.d/ sync
    gum spin --title "Waiting for Cilium daemonset..." -- kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
    gum spin --title "Waiting for nodes..." -- kubectl wait nodes --all --for=condition=Ready --timeout=300s

[doc('Install Flux components')]
flux:
    #!/usr/bin/env bash
    set -euo pipefail
    just log info "Installing Flux..."
    flux check --pre
    kubectl apply --server-side --kustomize {{ bootstrap_dir }}
    just log info "Waiting for Flux controllers..."
    kubectl -n flux-system rollout status deployment/source-controller --timeout=120s
    kubectl -n flux-system rollout status deployment/kustomize-controller --timeout=120s

[doc('Apply Flux secrets')]
flux-secrets:
    just log info "Applying Flux secrets..."
    sops --decrypt {{ bootstrap_dir }}/age-key.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt {{ bootstrap_dir }}/github-deploy-key.sops.yaml | kubectl apply --server-side -f -
    sops --decrypt {{ flux_dir }}/vars/cluster-secrets.sops.yaml | kubectl apply --server-side -f -

[doc('Start Flux reconciliation')]
flux-config:
    #!/usr/bin/env bash
    just log info "Applying Flux configuration..."
    kubectl apply --server-side --kustomize {{ flux_dir }}/config

    just log info "Verifying Flux installation..."
    flux check

[doc('Install only Cilium (for existing clusters)')]
helmfile-only:
    @just bootstrap helmfile-sync
