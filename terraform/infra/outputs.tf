output "bastion_public_ip" {
  value = module.bastion.public_ips[0]
}

output "private_ips" {
  value = {
    bastion = var.bastion_ip
    master  = var.master_ip
    workers = var.worker_ips
  }
}

output "nat_public_ip" {
  value = module.networking.nat_public_ip
}

output "ssh_config" {
  description = "Pegar en ~/.ssh/config para entrar con: ssh bastion | ssh master | ssh worker01"
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
    flatten([for i, ip in var.worker_ips : [
      "",
      format("Host worker%02d", i + 1),
      "  HostName ${ip}",
      "  User rocky",
      "  ProxyJump bastion",
    ]]),
  ))
}
