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

### Kubernetes VIP
`192.168.42.100`
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
