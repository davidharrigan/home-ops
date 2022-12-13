resource "proxmox_vm_qemu" "game" {
  name        = "valheim-1"
  target_node = "proxmox"
  clone       = "ubuntu-jammy-cloud"
  vmid        = "500"

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 8
  sockets  = 2
  cpu      = "host"
  memory   = 16384
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = 0
    size     = "40G"
    type     = "scsi"
    storage  = "fast"
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
  ipconfig0 = "ip=192.168.60.1/16,gw=192.168.10.1"
}
