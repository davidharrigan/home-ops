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

3. Add the Age key in order for Flux to decrypt SOPS secrets

```bash
cat $(echo $SOPS_AGE_KEY_FILE) |
    kubectl \
    -n flux-system create secret generic sops-age \
    --from-file=age.agekey=/dev/stdin
```

4. Add this to `gotk-sync.yaml` (TODO)

```
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

5. Verify Flux components are running

```bash
kubectl get pods -n flux-system
```

## Current Pain Points

### Resolving Dependencies

`nginx-ingress` is now in `system` since it's needed by other resources in
`system`. there's a dep issue currently with `certificate` where because the
secret is not there yet, the resource fails to be created. Workaround now is to
comment out the wildcard `certificate` resource on a fresh install.

### Nginx Ingress Controller

Something is already installing nginx? Have to remove these manually:

```bash
kubectl delete validatingwebhookconfiguration ingress-nginx-admission
kubectl delete clusterrolebinding ingress-nginx-admission
kubectl delete clusterrole ingress-nginx-admission
kubectl delete clusterrolebinding ingress-nginx
kubectl delete clusterrole ingress-nginx
kubectl delete ingressclass nginx
```

### Setting up plex server

Plex server setup can't be done through external IP. We need to port-foward the
service and setup plex-server on the first time setup.

```bash
kubectl port-forward service/plex -n media 32400:32400
```

go to http://localhost:32400/web/index.html in your browser.
