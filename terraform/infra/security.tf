# Security groups por rol, con los mismos puertos que el taller abre en firewalld.
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/

resource "aws_security_group" "bastion" {
  name        = "${var.project}-bastion"
  description = "Bastion: SSH de administracion"
  vpc_id      = module.networking.vpc_id
  tags        = { Name = "${var.project}-bastion" }
}

resource "aws_security_group" "master" {
  name        = "${var.project}-master"
  description = "Control plane de Kubernetes"
  vpc_id      = module.networking.vpc_id
  tags        = { Name = "${var.project}-master" }
}

resource "aws_security_group" "worker" {
  name        = "${var.project}-worker"
  description = "Workers de Kubernetes"
  vpc_id      = module.networking.vpc_id
  tags        = { Name = "${var.project}-worker" }
}

locals {
  sg = {
    bastion = aws_security_group.bastion.id
    master  = aws_security_group.master.id
    worker  = aws_security_group.worker.id
  }

  # Cada regla: sg destino, protocolo, puertos y origen (otro SG o un CIDR)
  ingress_rules = {
    # ----- Bastión -----
    bastion_ssh  = { sg = "bastion", proto = "tcp", from = 22, to = 22, cidr = var.admin_cidr, desc = "SSH desde el administrador" }
    bastion_icmp = { sg = "bastion", proto = "icmp", from = -1, to = -1, cidr = var.vpc_cidr, desc = "Ping dentro de la VPC" }

    # ----- Master (control plane) -----
    master_ssh            = { sg = "master", proto = "tcp", from = 22, to = 22, src = "bastion", desc = "SSH desde el bastion" }
    master_api_bastion    = { sg = "master", proto = "tcp", from = 6443, to = 6443, src = "bastion", desc = "API server (kubectl desde el bastion)" }
    master_api_worker     = { sg = "master", proto = "tcp", from = 6443, to = 6443, src = "worker", desc = "API server desde workers" }
    master_api_self       = { sg = "master", proto = "tcp", from = 6443, to = 6443, src = "master", desc = "API server" }
    master_etcd           = { sg = "master", proto = "tcp", from = 2379, to = 2380, src = "master", desc = "etcd server client API" }
    master_kubelet        = { sg = "master", proto = "tcp", from = 10250, to = 10250, src = "master", desc = "Kubelet API" }
    master_scheduler      = { sg = "master", proto = "tcp", from = 10259, to = 10259, src = "master", desc = "kube-scheduler" }
    master_controller     = { sg = "master", proto = "tcp", from = 10257, to = 10257, src = "master", desc = "kube-controller-manager" }
    master_nodeports      = { sg = "master", proto = "tcp", from = 30000, to = 32767, src = "bastion", desc = "NodePort Services desde el bastion" }
    master_flannel_worker = { sg = "master", proto = "udp", from = 8472, to = 8472, src = "worker", desc = "Flannel VXLAN" }
    master_flannel_self   = { sg = "master", proto = "udp", from = 8472, to = 8472, src = "master", desc = "Flannel VXLAN" }
    master_icmp           = { sg = "master", proto = "icmp", from = -1, to = -1, cidr = var.vpc_cidr, desc = "Ping dentro de la VPC" }

    # ----- Worker -----
    worker_ssh            = { sg = "worker", proto = "tcp", from = 22, to = 22, src = "bastion", desc = "SSH desde el bastion" }
    worker_kubelet        = { sg = "worker", proto = "tcp", from = 10250, to = 10250, src = "master", desc = "Kubelet API desde el control plane" }
    worker_kube_proxy     = { sg = "worker", proto = "tcp", from = 10256, to = 10256, src = "master", desc = "kube-proxy health check" }
    worker_nodeports      = { sg = "worker", proto = "tcp", from = 30000, to = 32767, src = "bastion", desc = "NodePort Services desde el bastion" }
    worker_nodeports_self = { sg = "worker", proto = "tcp", from = 30000, to = 32767, src = "worker", desc = "NodePort Services entre workers" }
    worker_flannel_master = { sg = "worker", proto = "udp", from = 8472, to = 8472, src = "master", desc = "Flannel VXLAN" }
    worker_flannel_self   = { sg = "worker", proto = "udp", from = 8472, to = 8472, src = "worker", desc = "Flannel VXLAN" }
    worker_icmp           = { sg = "worker", proto = "icmp", from = -1, to = -1, cidr = var.vpc_cidr, desc = "Ping dentro de la VPC" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id            = local.sg[each.value.sg]
  ip_protocol                  = each.value.proto
  from_port                    = each.value.from
  to_port                      = each.value.to
  cidr_ipv4                    = try(each.value.cidr, null)
  referenced_security_group_id = try(local.sg[each.value.src], null)
  description                  = each.value.desc

  tags = { Name = each.key }
}

# Salida libre (internet vía IGW en el bastión y vía NAT en los nodos)
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = local.sg

  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida a internet"
}
