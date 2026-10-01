output "bastion_public_ip" {
  value = module.bastion.public_ips[0]
}

output "private_ips" {
  value = local.hosts
}

output "nat_public_ip" {
  value = module.networking.nat_public_ip
}

output "dns_zone_id" {
  description = "Zona privada directa (ver var.dns_domain)"
  value       = module.dns.zone_id
}

output "dns_reverse_zone_id" {
  description = "Zona privada inversa (ver local.dns_reverse_zone)"
  value       = module.dns_reverse.zone_id
}

output "region" {
  value = var.region
}

output "ecr_registry" {
  description = "Registro ECR (para docker login)"
  value       = local.ecr_registry
}

output "ecr_repository_urls" {
  description = "nombre => URL del repositorio, para usar en image: de los manifiestos"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "ssh_config" {
  description = "Pegar en ~/.ssh/config para entrar con: ssh bastion | ssh master | ssh worker"
  value = join("\n", concat(
    [
      "Host bastion",
      "  HostName ${module.bastion.public_ips[0]}",
      "  User rocky",
      "",
      "Host master",
      "  HostName ${var.master_ip}",
      "  User rocky",
      "  ProxyJump bastion",
    ],
    flatten([for name, ip in local.workers : [
      "",
      "Host ${name}",
      "  HostName ${ip}",
      "  User rocky",
      "  ProxyJump bastion",
    ]]),
  ))
}

output "ansible_inventory" {
  description = "Inventario generado para Ansible"
  value       = abspath(local_file.ansible_inventory.filename)
}
