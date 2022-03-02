# K8S Cluster

## First time setup

1. Check you have everything needed to run Flux by running the following command:
```bash
flux check --pre
```

2. Install fluxcd onto the cluster:
```bash
flux bootstrap github \
  --owner=davidharrigan \
  --repository=lab \
  --branch=main \
  --path=./cluster/fluxcd \
  --personal
```

3. Add the Age key in-order for Flux to decrypt SOPS secrets
```bash
cat $(echo $SOPS_AGE_KEY_FILE) |
    kubectl \
    -n flux-system create secret generic sops-age \
    --from-file=age.agekey=/dev/stdin
```

4. Verify Flux components are running
```bash
kubectl get pods -n flux-system
```
