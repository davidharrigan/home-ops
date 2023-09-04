## Prerequisites

### Development

- direnv
- sops
- [talosctl](https://www.talos.dev/latest/introduction/quickstart/)

## Networking

| Name                | CIDR              |
| ------------------- | ----------------- |
| Management          | `192.168.10.0/24` |
| Users               | `192.168.20.0/24` |
| Servers             | `192.168.42.0/24` |
| IoT                 | `192.168.50.0/24` |
| Kubernetes pods     | `10.42.0.0/16`    |
| Kubernetes services | `10.43.0.0/16`    |

### Servers VLAN

#### Fixed IPs

| Name              | IPs                               |
| ----------------- | --------------------------------- |
| DNS / DHCP        | `192.168.42.10`                   |
| Kube Endpoint VIP | `192.168.42.42`                   |
| Kube LB Range     | `192.168.42.50 - 192.168.42.60`   |
| DHCP Range        | `192.168.42.100 - 192.168.42.250` |

### Kubernetes VIP

- https://www.talos.dev/v1.4/talos-guides/network/vip/

## Secrets

### SOPS

#### Creating a new encrypted file

1. Create a new file ending in `<filename>.sops.yaml`
2. Add secrets
3. Encrypt it:

```bash
sops --encrypt --in-place <filename>
```

Alternatively, you can also use the below "decrypt" command and sops will create a file if it doesn't already exist.

#### Editing encrypted file

```bash
sops <filename> --decrypt
```
