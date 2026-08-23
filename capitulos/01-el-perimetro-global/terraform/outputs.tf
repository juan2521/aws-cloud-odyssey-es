output "cloudfront_url" {
  description = "URL pública de CloudFront."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "custom_url" {
  description = "URL personalizada si se configuró domain_name."
  value       = var.domain_name == null ? null : "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.app.id
}

output "internal_alb_dns_name" {
  description = "DNS privado del ALB. No está pensado para acceso directo desde Internet."
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "Endpoint privado de PostgreSQL."
  value       = aws_db_instance.postgres.address
}

output "database_username" {
  value = aws_db_instance.postgres.username
}

output "database_password" {
  description = "Contraseña generada para el laboratorio. Terraform la mantiene en el state; para producción usa Secrets Manager."
  value       = random_password.db.result
  sensitive   = true
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.edge.arn
}
