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
