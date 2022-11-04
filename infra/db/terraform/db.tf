resource "proxmox_vm_qemu" "db" {
  name        = "db-1"
  target_node = "proxmox"
  clone       = "ubuntu-jammy-cloud"
  vmid        = "600"

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 2048
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
  ipconfig0 = "ip=192.168.50.1/16,gw=192.168.10.1"
}
