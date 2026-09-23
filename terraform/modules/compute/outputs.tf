output "instance_ids" {
  value = aws_instance.this[*].id
}

output "private_ips" {
  value = aws_instance.this[*].private_ip
}

output "public_ips" {
  value = aws_instance.this[*].public_ip
}

output "instances" {
  description = "Mapa nombre => { id, private_ip, public_ip }"
  value = {
    for i in aws_instance.this : i.tags["Name"] => {
      id         = i.id
      private_ip = i.private_ip
      public_ip  = i.public_ip
    }
  }
}
