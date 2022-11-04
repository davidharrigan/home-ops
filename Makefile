# ------------------------------------------------
# bootstrapping
# ------------------------------------------------
.PHONY: pre-commit/init
pre-commit/init:
	pre-commit install --install-hooks
	pre-commit run --all-files

# ------------------------------------------------
# Ansible operations
# ------------------------------------------------
K3S_DIR="./infra/k3s"
K3S_ANSIBLE_INVENTORY_DIR="${K3S_DIR}/inventory"
K3S_ANSIBLE_PLAYBOOK_DIR="${K3S_DIR}/playbooks"

DB_DIR="./infra/db"
DB_ANSIBLE_INVENTORY_DIR="${DB_DIR}/inventory"
DB_ANSIBLE_PLAYBOOK_DIR="${DB_DIR}/playbooks"

.PHONY: ansible/deps
ansible/deps:
	ansible-galaxy install -r ./infra/requirements.yaml --force

.PHONY: k3s/list-hosts
k3s/list-hosts:
	ansible all -i ${K3S_ANSIBLE_INVENTORY_DIR}/hosts.yaml --list-hosts

.PHONY: ping
k3s/ping:
	ansible all -i ${K3S_DIR}/inventory/hosts.yaml --one-line -m 'ping'

.PHONY: k3s/playbook/prepare
k3s/playbook/prepare:
	ansible-playbook -i ${K3S_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${K3S_ANSIBLE_PLAYBOOK_DIR}/prepare.yaml

.PHONY: k3s/playbook/get_kubeconfig
k3s/playbook/get_kubeconfig:
	ansible-playbook -i ${K3S_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${K3S_ANSIBLE_PLAYBOOK_DIR}/get_kubeconfig.yaml

.PHONY: k3s/playbook/create_cluster
k3s/playbook/create_cluster:
	ansible-playbook -i ${K3S_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${K3S_ANSIBLE_PLAYBOOK_DIR}/create_cluster.yaml

.PHONY: k3s/playbook/destroy_cluster
k3s/playbook/destroy_cluster:
	ansible-playbook -i ${K3S_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${K3S_ANSIBLE_PLAYBOOK_DIR}/destroy_cluster.yaml

.PHONY: db/list-hosts
db/list-hosts:
	ansible all -i ${DB_ANSIBLE_INVENTORY_DIR}/hosts.yaml --list-hosts

.PHONY: db/ping
db/ping:
	ansible all -i ${DB_DIR}/inventory/hosts.yaml --one-line -m 'ping'

.PHONY: db/playbook/prepare
db/playbook/prepare:
	ansible-playbook -i ${DB_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${DB_ANSIBLE_PLAYBOOK_DIR}/prepare.yaml

.PHONY: db/playbook/db
db/playbook/db:
	ansible-playbook -i ${DB_ANSIBLE_INVENTORY_DIR}/hosts.yaml ${DB_ANSIBLE_PLAYBOOK_DIR}/db.yaml

# ------------------------------------------------
# Terraform
# ------------------------------------------------
k3s/terraform/plan:
	cd ${K3S_DIR}/terraform && terraform plan

k3s/terraform/apply:
	cd ${K3S_DIR}/terraform && terraform apply

db/terraform/plan:
	cd ${DB_DIR}/terraform && terraform plan

db/terraform/apply:
	cd ${DB_DIR}/terraform && terraform apply

# ------------------------------------------------
# FluxCD
# ------------------------------------------------
FLUXCD_DIR="./cluster/fluxcd"

.PHONY: _check_sops_defined
_check_sops_defined:
	test ${SOPS_AGE_KEY_FILE}

.PHONY: flux/install
flux/install: _check_sops_defined
	kubectl apply --kustomize ${FLUXCD_DIR}/bootstrap/
	cat ${SOPS_AGE_KEY_FILE} | kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/dev/stdin --save-config --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply --kustomize ${FLUXCD_DIR}/flux-system/
	sops -d ${FLUXCD_DIR}/bootstrap/github-deploy-key.sops.yaml | kubectl apply -f -

.PHONY: flux/reconcile
flux/reconcile:
	flux reconcile source git flux-system
