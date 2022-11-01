resource "proxmox_vm_qemu" "k8s-server" {
  count       = 3
  name        = "k8s-server-${count.index + 1}"
  target_node = "proxmox"
  clone       = "ubuntu-jammy-cloud"
  vmid        = "70${count.index}"

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 6144
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = 0
    size     = "20G"
    type     = "scsi"
    storage  = "ssd"
    iothread = 1
  }
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  ipconfig0 = "ip=192.168.20.${count.index + 1}/16,gw=192.168.10.1"
}

resource "proxmox_vm_qemu" "k8s-agent" {
  count       = 2
  name        = "k8s-agent-${count.index + 1}"
  target_node = "proxmox"
  clone       = "ubuntu-jammy-cloud"
  vmid        = "80${count.index}"

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 4096
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = 0
    size     = "20G"
    type     = "scsi"
    storage  = "ssd"
    iothread = 1
  }
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  ipconfig0 = "ip=192.168.30.${count.index + 1}/16,gw=192.168.10.1"
}
