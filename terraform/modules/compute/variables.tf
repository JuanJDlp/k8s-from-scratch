variable "name" {
  description = "Prefijo del nombre de las instancias (ej: k8s-control-plane)"
  type        = string
}

variable "instance_count" {
  description = "Cantidad de instancias a crear"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI a usar. Si es null se busca la más reciente con ami_owners / ami_name_pattern"
  type        = string
  default     = null
}

variable "ami_owners" {
  description = "Owners de la AMI a buscar (por defecto la cuenta oficial de Rocky Linux)"
  type        = list(string)
  default     = ["792107900819"]
}

variable "ami_name_pattern" {
  description = "Patrón del nombre de la AMI a buscar"
  type        = string
  default     = "Rocky-9-EC2-Base-9.7-*"
}

variable "subnet_id" {
  description = "Subnet donde se lanzan las instancias"
  type        = string
}

variable "private_ips" {
  description = "IPs privadas fijas, una por instancia (vacío = asignación automática)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.private_ips) == 0 || length(var.private_ips) == var.instance_count
    error_message = "private_ips debe estar vacío o tener exactamente instance_count elementos."
  }
}

variable "security_group_ids" {
  description = "Security groups asociados a las instancias"
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "Asignar IP pública (solo tiene sentido en subnet pública)"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "Nombre del key pair de EC2 para SSH (opcional)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Tamaño del disco raíz en GiB"
  type        = number
  default     = 20
}

variable "user_data" {
  description = "Script de cloud-init / user data"
  type        = string
  default     = null
}

variable "source_dest_check" {
  description = "Poner en false si la instancia enruta tráfico de pods (algunos CNIs lo requieren)"
  type        = bool
  default     = true
}

variable "enable_ssm" {
  description = "Crear un instance profile con acceso a SSM Session Manager"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionales para las instancias"
  type        = map(string)
  default     = {}
}
