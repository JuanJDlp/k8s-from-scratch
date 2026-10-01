# Registro privado para las imágenes de las apps (taller-2-apps).
# Los nodos descargan con su rol IAM a través del ecr-credential-provider del
# kubelet (rol de Ansible ecr_credential_provider): no hace falta imagePullSecret.
locals {
  # Solo lectura: ecr:GetAuthorizationToken, BatchGetImage, GetDownloadUrlForLayer
  ecr_pull_policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"

  # <cuenta>.dkr.ecr.<región>.amazonaws.com
  ecr_registry = split("/", aws_ecr_repository.this[var.ecr_repositories[0]].repository_url)[0]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repositories)

  name                 = "${var.project}/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # `make down` borra el repo aunque tenga imágenes

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Solo se guardan las últimas imágenes para no acumular costo de almacenamiento
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar las últimas ${var.ecr_keep_images} imágenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_keep_images
      }
      action = { type = "expire" }
    }]
  })
}
