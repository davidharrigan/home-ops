# Getting Started

## Prerequisites
- [ansible](https://www.ansible.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [age](https://github.com/FiloSottile/age)
- [direnv](https://github.com/direnv/direnv)
- [pre-commit](https://github.com/pre-commit/pre-commit)

### pre-commit
Install pre-commit hooks:
```bash
make pre-commit/init
```

### Setting up Age
1. Create a Age Private / Public key
```bash
age-keygen -o age.agekey
```
2. Move the generated key
```bash
mkdir -p ~/.config/sops/age
mv age.agekey ~/.config/sops/age/labkeys.txt
```
3. Export `SOPS_AGE_KEY_FILE` variable in `.envrc`
```bash
echo export SOPS_AGE_KEY_FILE=~/.config/sops/age/labkeys.txt > .envrc
```
4. Ensure the public key matches the configuration in `.sops.yaml`

### Direnv
Allow .envrc to be loaded by direnv
```bash
direnv allow .
```
