# Ansible

## First time
1. Install galaxy dependencies:
```bash
make ansible/deps
```

2. Make sure host inventory is setup correctly:
```bash
make ansible/list
```

3. Ping all hosts:
```bash
make ansible/ping
```

## Bootstrapping Ubuntu Nodes
```bash
make ansible/playbook/ubuntu-prepare
```
