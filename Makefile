# Flujo completo:  make up   (terraform apply + playbook)
#                  make down (terraform destroy)
TF      := terraform -chdir=terraform/infra
ANSIBLE := cd ansible &&

# Si terraform.tfvars no define admin_cidr, se usa tu IP pública actual
export TF_VAR_admin_cidr ?= $(shell curl -s https://checkip.amazonaws.com)/32

.PHONY: up infra cluster deps ping down

up: infra cluster

infra:
	$(TF) init -input=false
	$(TF) apply -auto-approve

deps:
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml

cluster: deps
	$(ANSIBLE) ansible-playbook playbooks/site.yml

ping:
	$(ANSIBLE) ansible all -m ansible.builtin.ping

down:
	$(TF) destroy -auto-approve
