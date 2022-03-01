# Working with SOPS

## Creating a new encrypted file
1. Create a new file ending in `<filename>.sops.yaml`
2. Add secrets
3. Encrypt it:
```bash
sops --encrypt --in-place <filename>
```

Alternatively, you can also use the below "decrypt" command and sops will create a file if it doesn't already exist.

## Editing encrypted file
```bash
sops <filename> --decrypt
```
