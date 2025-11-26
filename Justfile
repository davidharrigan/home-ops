# Home-ops Justfile
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

root_dir := justfile_dir()
talos_dir := root_dir / "cluster/talos"

config_dir := talos_dir / "generated"
export TALOS_CONFIG_DIR := config_dir

talosconfig := root_dir / "cluster/talos/generated/talosconfig"
export TALOSCONFIG := talosconfig

# Modules
mod talos 'cluster/talos/mod.just'
mod bootstrap 'cluster/bootstrap/mod.just'


[private]
default:
    @just -l

[no-exit-message]
[private]
fatal msg:
    gum log --level error "{{ msg }}"
    exit 1

[private]
log first='' *rest='':
    {{ if first =~ '^(debug|info|warn|error)$' { 'gum log --level ' + first + ' "' + rest + '"' } else { 'gum log --level info "' + first + ' ' + rest + '"' } }}
