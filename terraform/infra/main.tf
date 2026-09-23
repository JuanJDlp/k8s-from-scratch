resource "aws_key_pair" "this" {
  key_name   = "${var.project}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

module "networking" {
  source = "../modules/networking"

  name                = var.project
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

locals {
  # Reversa de los dos primeros octetos de la VPC (10.0.0.0/16 -> 0.10.in-addr.arpa)
  vpc_octets       = split(".", split("/", var.vpc_cidr)[0])
  dns_reverse_zone = "${local.vpc_octets[1]}.${local.vpc_octets[0]}.in-addr.arpa"

  # Nombre PTR relativo a la zona inversa (10.0.2.10 -> "10.2")
  ptr_name = { for host, ip in {
    bastion = var.bastion_ip
    master  = var.master_ip
    worker  = var.worker_ips[0]
    } : host => "${split(".", ip)[3]}.${split(".", ip)[2]}"
  }
}

# Zona directa: bastion.k8s.lab, master.k8s.lab, worker.k8s.lab
module "dns" {
  source = "../modules/route53"

  domain_name = var.dns_domain
  vpc_id      = module.networking.vpc_id
  vpc_region  = var.region
  comment     = "Zona privada del cluster ${var.project}"

  records = {
    bastion = [var.bastion_ip]
    master  = [var.master_ip]
    worker  = [var.worker_ips[0]]
  }
}

# Zona inversa: resuelve las IPs privadas a bastion/master/worker.k8s.lab
module "dns_reverse" {
  source = "../modules/route53"

  domain_name = local.dns_reverse_zone
  vpc_id      = module.networking.vpc_id
  vpc_region  = var.region
  comment     = "Zona inversa del cluster ${var.project}"
  record_type = "PTR"

  records = {
    (local.ptr_name.bastion) = ["bastion.${var.dns_domain}."]
    (local.ptr_name.master)  = ["master.${var.dns_domain}."]
    (local.ptr_name.worker)  = ["worker.${var.dns_domain}."]
  }
}

# Bastión: punto de administración con kubectl
module "bastion" {
  source = "../modules/compute"

  name                = "${var.project}-bastion"
  instance_type       = var.bastion_instance_type
  subnet_id           = module.networking.public_subnet_id
  private_ips         = [var.bastion_ip]
  associate_public_ip = true
  security_group_ids  = [aws_security_group.bastion.id]
  key_name            = aws_key_pair.this.key_name

  tags = { Role = "bastion" }
}

module "master" {
  source = "../modules/compute"

  name               = "${var.project}-master"
  instance_type      = var.master_instance_type
  subnet_id          = module.networking.private_subnet_id
  private_ips        = [var.master_ip]
  security_group_ids = [aws_security_group.master.id]
  key_name           = aws_key_pair.this.key_name

  tags = { Role = "control-plane" }
}

module "worker" {
  source = "../modules/compute"

  name               = "${var.project}-worker"
  instance_count     = length(var.worker_ips)
  instance_type      = var.worker_instance_type
  subnet_id          = module.networking.private_subnet_id
  private_ips        = var.worker_ips
  security_group_ids = [aws_security_group.worker.id]
  key_name           = aws_key_pair.this.key_name

  tags = { Role = "worker" }
}
