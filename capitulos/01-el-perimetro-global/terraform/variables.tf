variable "project_name" {
  description = "Prefijo usado para nombrar los recursos."
  type        = string
  default     = "cloud-odyssey-cap01"
}

variable "aws_region" {
  description = "Región principal donde se desplegará la aplicación."
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "instance_type" {
  description = "Tipo de instancia para la capa de aplicación."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Clase de instancia para RDS PostgreSQL."
  type        = string
  default     = "db.t4g.micro"
}

variable "domain_name" {
  description = "Dominio opcional, por ejemplo app.midominio.com. Déjalo en null para usar el dominio de CloudFront."
  type        = string
  default     = null
  nullable    = true
}

variable "hosted_zone_id" {
  description = "Hosted Zone ID de Route 53. Obligatorio solo si domain_name no es null."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "hosted_zone_id debe definirse cuando domain_name tiene un valor."
  }
}

variable "waf_rate_limit" {
  description = "Máximo de solicitudes por ventana de evaluación para la regla rate-based del WAF."
  type        = number
  default     = 2000
}
