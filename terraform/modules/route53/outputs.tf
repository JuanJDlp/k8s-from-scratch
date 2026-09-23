output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "domain_name" {
  value = var.domain_name
}

output "name_servers" {
  description = "Name servers de la zona (informativo; no aplican fuera de la VPC en zonas privadas)"
  value       = aws_route53_zone.this.name_servers
}
