variable "domain_name" {
  description = "Nombre de dominio de la zona privada (ej: k8s.internal)"
  type        = string
}

variable "vpc_id" {
  description = "VPC a la que se asocia la zona privada"
  type        = string
}

variable "vpc_region" {
  description = "Región de la VPC asociada. Si es null se usa la región del provider"
  type        = string
  default     = null
}

variable "comment" {
  description = "Comentario descriptivo de la zona hospedada"
  type        = string
  default     = "Private hosted zone"
}

variable "record_type" {
  description = "Tipo de los registros en `records` (A para la zona directa, PTR para la zona inversa)"
  type        = string
  default     = "A"

  validation {
    condition     = contains(["A", "PTR", "CNAME"], var.record_type)
    error_message = "record_type debe ser A, PTR o CNAME"
  }
}

variable "records" {
  description = "Registros a crear en la zona, en la forma { nombre = [valores] }. El nombre es relativo al dominio (ej: master -> master.k8s.lab). Para PTR, el nombre es el octeto invertido (ej: 10.2 en la zona 0.10.in-addr.arpa) y el valor el hostname"
  type        = map(list(string))
  default     = {}
}

variable "ttl" {
  description = "TTL en segundos para los registros"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags adicionales para la zona hospedada"
  type        = map(string)
  default     = {}
}
