# Talos module
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

# Configuration
talos_version := "v1.12.0"
architecture := "amd64"
cluster_name := "home_cluster"
cluster_endpoint := "k8s-vip.lan"
factory_url := "https://factory.talos.dev"

# Directories
root_dir := justfile_dir()
talos_dir := root_dir / "cluster/talos"
patches_dir := talos_dir / "patches"
machines_dir := talos_dir / "machines"
output_dir := talos_dir / "generated"
secrets_file := talos_dir / "secret.sops.yaml"
schematic_file := talos_dir / "schematic.yaml"
downloads_dir := talos_dir / "downloads"

tempdir := `mktemp -d`
secrets_tmpfile := join(tempdir, "talos-" + sha256_file(secrets_file) + ".yaml")

[private]
default:
    @just --list talos

# Decrypt secrets if not already decrypted (idempotent)
[private]
decrypt-secrets:
    #!/usr/bin/env bash
    test -f {{ secrets_tmpfile }} || (sops --decrypt {{ secrets_file }} > {{ secrets_tmpfile }} && (
        while kill -0 {{ just_pid() }} 2>/dev/null; do sleep 1; done
        rm -f {{ secrets_tmpfile }}
    ) &)

[private]
node-exists node:
    test -f {{ machines_dir }}/{{ node }}.yaml || just fatal "Node '{{ node }}' not found in {{ machines_dir }}"

[private]
is-controller node:
    [ $(just talos machine-type "{{ machines_dir }}/{{ node }}.yaml") = "controlplane" ]

# Get machine type from machine file
[private]
machine-type file:
    yq eval '.machine.type // "worker"' {{ file }}

[private]
output-dir:
    mkdir -p {{ output_dir }}

[doc('Show cluster info')]
info:
    #!/usr/bin/env bash
    set -euo pipefail
    gum style \
        --border rounded --border-foreground 212 \
        --padding "0 1" --margin "0" \
        "$(gum style --bold --foreground 212 'Talos Cluster Info')" \
        "" \
        "Cluster:   $(gum style --foreground 39 '{{ cluster_name }}')" \
        "Endpoint:  $(gum style --foreground 39 '{{ cluster_endpoint }}')" \
        "Version:   $(gum style --foreground 39 '{{ talos_version }}')"

    echo ""
    just log info "Machines:"
    for m in {{ machines_dir }}/*.yaml; do
        [ -e "$m" ] || continue
    name=$(basename "$m" .yaml)
    type=$(just talos machine-type "$m")
    echo "  • $name ($type)"
    done

[doc('Clean generated configurations')]
clean:
    rm -rf {{ output_dir }}/*
    just log info "Cleaned {{ output_dir }}/"

gen: gen-config gen-talosconfig

[private]
_gen-config *flags: decrypt-secrets
    talosctl gen config {{ cluster_name }} https://{{ cluster_endpoint }}:6443 \
        --with-secrets {{ secrets_tmpfile }} \
        --config-patch @{{ patches_dir }}/common.yaml \
        --config-patch-control-plane @{{ patches_dir }}/controlplane.yaml \
        --config-patch-worker @{{ patches_dir }}/worker.yaml \
        --force \
        {{ flags }} >/dev/null 2>&1

[doc('Generate config for a single machine')]
gen-machineconfig node: (node-exists node) output-dir
    #!/usr/bin/env bash
    set -euo pipefail
    config={{ join(machines_dir,  node + ".yaml") }}
    just talos _gen-config \
        --config-patch @$config \
        --output-types $(just talos machine-type $config) \
        --output {{ output_dir }}/{{ node }}.yaml
    just log "generated machine config: {{ output_dir }}/{{ node }}.yaml"

[doc('Generate Talos machine configurations')]
gen-config:
    for machine in {{ machines_dir }}/*.yaml; do \
        just talos gen-machineconfig "$(basename ${machine%.yaml})"; done

[doc('Generate talosconfig')]
gen-talosconfig: output-dir
    just talos _gen-config \
        --output-types talosconfig \
        --output $TALOSCONFIG
    just log "generated talosconfig: $TALOSCONFIG"

[doc('Set talosconfig to all machine endpoints and nodes')]
set-config:
    talosctl config endpoint "$endpoints" # do not set to VIPs
    talosctl config nodes $nodes

endpoints:
    #!/usr/bin/env bash
    set -euo pipefail
    for m in {{ machines_dir }}/*.yaml; do
        type=$(just talos machine-type "$m")
        hostname=$(yq eval '.machine.network.hostname' "$m")
        if [ "$type" = "controlplane" ]; then
            echo ${hostname}.lan
        fi
    done

nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    for m in {{ machines_dir }}/*.yaml; do
        hostname=$(yq eval '.machine.network.hostname' "$m")
        echo ${hostname}.lan
    done

[doc('Get schematic ID from Talos Image Factory')]
schematic file=schematic_file:
    curl -sS -X POST \
        -H "Content-Type: application/x-yaml" \
        --data-binary @{{ file }} \
        {{ factory_url }}/schematics | jq -r '.id'

[doc('Download Talos installer ISO')]
download file=schematic_file:
    #!/usr/bin/env bash
    set -euo pipefail

    schematic_id=$(just talos schematic {{ file }})
    iso_name="talos-{{ talos_version }}-{{ architecture }}-${schematic_id:0:8}.iso"
    iso_path="{{ downloads_dir }}/${iso_name}"

    mkdir -p {{ downloads_dir }}

    if [ -f "$iso_path" ]; then
        just log info $iso_path already exists
        echo "$iso_path"
        exit 0
    fi

    image_url="{{ factory_url }}/image/${schematic_id}/{{ talos_version }}/metal-{{ architecture }}.iso"

    gum spin --title "Downloading Talos {{ talos_version }}@$schematic_id ..." -- curl -sSL -o "$iso_path" "$image_url" >&2
    echo $iso_path

[doc('Write Talos installer to USB device')]
usb device file=schematic_file:
    #!/usr/bin/env bash
    set -euo pipefail

    iso_path=$(just talos download {{ file }})
    iso_name=$(basename "$iso_path")

    gum style \
        --border rounded --border-foreground 212 \
        --padding "0 1" --margin "0" \
        "$(gum style --bold --foreground 212 'Talos USB Writer')" \
        "" \
        "Version:  $(gum style --foreground 39 '{{ talos_version }}')" \
        "Arch:     $(gum style --foreground 39 '{{ architecture }}')" \
        "Image:    $(gum style --foreground 39 "${iso_name}")" \
        "Device:   $(gum style --foreground 39 '{{ device }}')"

    echo ""

    [ -e "{{ device }}" ] || just fatal "Device {{ device }} does not exist"
    mount | grep -q "{{ device }}" && just fatal "Device {{ device }} is mounted. Unmount first."

    just log warn "This will ERASE ALL DATA on {{ device }}"
    gum confirm "Write image to {{ device }}?" || just fatal "Aborted."
    sudo dd if="$iso_path" of={{ device }} bs=4M conv=fsync status=progress
    just log info "Done! You can now boot from {{ device }}"

[doc('Apply Talos config to a single node')]
apply node *args:
    talosctl apply-config -n "{{ node }}" --file="{{ output_dir }}/{{ node }}.yaml" {{ args }}
    just log "Config applied to {{ node }}"
