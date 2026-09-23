# Inventario de Ansible generado en cada apply: la IP pública del bastión cambia
# con cada recreación, las privadas no. Ver ansible/README.md
resource "local_file" "ansible_inventory" {
  filename = coalesce(
    var.ansible_inventory_path == null ? null : pathexpand(var.ansible_inventory_path),
    "${path.module}/../../ansible/inventories/aws/hosts.yml",
  )
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    ssh_user          = var.ssh_user
    ssh_key           = pathexpand(var.ssh_private_key_path)
    bastion_public_ip = module.bastion.public_ips[0]
    bastion_ip        = var.bastion_ip
    master_ip         = var.master_ip
    workers           = local.workers
    dns_domain        = var.dns_domain
    vpc_cidr          = var.vpc_cidr
  })
}
