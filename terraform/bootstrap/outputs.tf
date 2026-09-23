output "state_bucket" {
  description = "Nombre del bucket de estado (usar en infra/backend.tf)"
  value       = aws_s3_bucket.tfstate.id
}

output "region" {
  value = var.region
}
