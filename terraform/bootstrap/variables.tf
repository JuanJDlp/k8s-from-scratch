variable "region" {
  description = "Región de AWS donde se crea el bucket de estado"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto, usado como prefijo de recursos"
  type        = string
  default     = "k8s-from-scratch"
}
