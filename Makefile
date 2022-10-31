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
ANSIBLE_DIR="./infra"
ANSIBLE_INVENTORY_DIR="${ANSIBLE_DIR}/inventory"
ANSIBLE_PLAYBOOK_DIR="${ANSIBLE_DIR}/playbooks"

.PHONY: ansible/deps
ansible/deps:
	ansible-galaxy install -r ${ANSIBLE_DIR}/requirements.yaml --force

.PHONY: ansible/list
ansible/list:
	ansible all -i ${ANSIBLE_INVENTORY_DIR}/hosts.yaml --list-hosts

.PHONY: ping
ansible/ping:
	ansible all -i ${ANSIBLE_DIR}/inventory/hosts.yaml --one-line -m 'ping'

.PHONY: ansible/playbook/prepare
ansible/playbook/prepare:
	ansible-playbook -i ${ANSIBLE_INVENTORY_DIR}/hosts.yaml ${ANSIBLE_PLAYBOOK_DIR}/prepare.yaml

.PHONY: ansible/playbook/create_cluster
ansible/playbook/create_cluster:
	ansible-playbook -i ${ANSIBLE_INVENTORY_DIR}/hosts.yaml ${ANSIBLE_PLAYBOOK_DIR}/create_cluster.yaml

.PHONY: ansible/playbook/destroy_cluster
ansible/playbook/destroy_cluster:
	ansible-playbook -i ${ANSIBLE_INVENTORY_DIR}/hosts.yaml ${ANSIBLE_PLAYBOOK_DIR}/destroy_cluster.yaml

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
	cat ${SOPS_AGE_KEY_FILE} | kubectl -n flux-system create secret generic sops-age --from-file=age.agekey=/dev/stdin
	kubectl apply --kustomize ${FLUXCD_DIR}/flux-system/

.PHONY: flux/reconcile
flux/reconcile:
	flux reconcile source git flux-system

# ------------------------------------------------
# Terraform
# ------------------------------------------------
