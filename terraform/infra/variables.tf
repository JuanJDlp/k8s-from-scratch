variable "region" {
  description = "Región de AWS del cluster"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto, usado como prefijo de recursos"
  type        = string
  default     = "k8s-from-scratch"
}

# ---------- Acceso ----------
variable "admin_cidr" {
  description = "CIDR desde el que se permite SSH al bastión (tu IP pública, ej: 1.2.3.4/32)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Llave pública SSH que se instala en las 3 VMs"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ---------- Red ----------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Subnet pública: bastión (equivale a la red Bridge/NAT del taller)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Subnet privada: master y worker (equivale a la Red Interna del taller)"
  type        = string
  default     = "10.0.2.0/24"
}


# ---------- IPs privadas fijas ----------
variable "bastion_ip" {
  type    = string
  default = "10.0.1.10"
}

variable "master_ip" {
  type    = string
  default = "10.0.2.10"
}

variable "worker_ips" {
  description = "Una IP por worker; la cantidad de workers sale de esta lista"
  type        = list(string)
  default     = ["10.0.2.20"]
}

# ---------- DNS ----------
variable "dns_domain" {
  description = "Dominio privado de la zona Route 53 (ver cluster.md, Fase 1)"
  type        = string
  default     = "k8s.lab"
}

# ---------- Tamaños ----------
variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "master_instance_type" {
  description = "Taller: mínimo 2 vCPU / 2 GiB (c7i-flex.large = 2 vCPU / 4 GiB)"
  type        = string
  default     = "c7i-flex.large"
}

variable "worker_instance_type" {
  description = "Taller: mínimo 1 vCPU / 2 GiB (c7i-flex.large = 2 vCPU / 4 GiB)"
  type        = string
  default     = "c7i-flex.large"
}

# ---------- Ansible ----------
variable "ssh_user" {
  description = "Usuario por defecto de la AMI (Rocky Linux = rocky)"
  type        = string
  default     = "rocky"
}

variable "ssh_private_key_path" {
  description = "Llave privada que usa Ansible (pareja de ssh_public_key_path)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ansible_inventory_path" {
  description = "Dónde se escribe el inventario de Ansible. null = ansible/inventories/aws/hosts.yml del repo"
  type        = string
  default     = null
}
