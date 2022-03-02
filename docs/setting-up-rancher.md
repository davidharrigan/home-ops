# Setting up Rancher

Steps for setting up single node rancher. This will run Rancher on the master node. Kubernetes cluster will be setup using Rancher GUI for the master, and worker nodes.

Note: this is currently a manual process.

1. Install docker on k8s nodes
```bash
make ansible/playbook/docker-install
```

2. [Run single node rancher](https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/single-node-docker/#option-a-default-rancher-generated-self-signed-certificate) on the master node.
```bash
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  --privileged \
  rancher/rancher:latest
```

3. Setup Rancher from web browser
