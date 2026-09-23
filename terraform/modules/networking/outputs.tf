output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "availability_zone" {
  value = local.az
}

output "nat_public_ip" {
  description = "IP pública de salida de la subnet privada"
  value       = aws_eip.nat.public_ip
}
