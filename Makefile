# Flujo completo:  make up   (terraform apply + playbook)
#                  make down (terraform destroy)
TF      := terraform -chdir=terraform/infra
ANSIBLE := cd ansible &&

# Si terraform.tfvars no define admin_cidr, se usa tu IP pública actual
export TF_VAR_admin_cidr ?= $(shell curl -s https://checkip.amazonaws.com)/32

# Imagen de la app del taller 2:  make image [TAG=v2]
APP_DIR := taller-2-apps/K8S-apps
APP     := webapp
TAG     ?= v1

.PHONY: up infra cluster deps ping ecr ecr-login image down

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

# Clúster ya creado: aplica ECR + permisos IAM y configura solo el kubelet
ecr: infra deps
	$(ANSIBLE) ansible-playbook playbooks/site.yml --tags ecr

ecr-login:
	aws ecr get-login-password --region $$($(TF) output -raw region) | \
		docker login --username AWS --password-stdin $$($(TF) output -raw ecr_registry)

# linux/amd64: los nodos son x86_64 aunque se construya desde otra arquitectura
image: ecr-login
	repo=$$($(TF) output -json ecr_repository_urls | jq -r '.["$(APP)"]') && \
	docker build --platform linux/amd64 -t $$repo:$(TAG) $(APP_DIR) && \
	docker push $$repo:$(TAG) && \
	echo "Imagen: $$repo:$(TAG)"

down:
	$(TF) destroy -auto-approve
