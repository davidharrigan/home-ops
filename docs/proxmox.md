# Creating a VM Template

- Fetch a cloud-init Ubuntu image

```bash
wget https://cloud-images.ubuntu.com/...
```

- Create VM

```bash
# 8000 is the vm ID
qm create 8000 --memory 2048 --name ubuntu-jammy-cloud --net0 virtio,bridge=vmbr0
```

- Import Disk to `ssd` storage

```bash
# 8000 is the vm ID from the previous command
# ssd is the storage in Proxmox
qm importdisk 8000 jammy-server-cloudimg-amd64.img ssd
```

- Attach the new disk to the vm as a scsi drive on the scsi controller

```bash
qm set 8000 --scsihw virtio-scsi-pci --scsi0 ssd:vm-8000-disk-0
```

- Add cloudinit drive

```bash
qm set 8000 --ide2 ssd:cloudinit
```

- Make the cloud init drive bootable

```bash
qm set 8000 --boot c --bootdisk scsi0
```

- Add serial console

```bash
qm set 8000 --serial0 socket --vga serial0
```

Now enter cloudinit options from the Proxmox UI and create template.
