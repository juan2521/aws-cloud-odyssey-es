# 🚀 Despliegue con Terraform — Capítulo 01

Este código crea una implementación reproducible de **El Perímetro Global**.

## Qué despliega

```text
Internet
   ↓
Amazon Route 53 (opcional)
   ↓
Amazon CloudFront
   ↓
AWS WAF
   ↓
CloudFront VPC Origin
   ↓
Internal Application Load Balancer
   ↓
Auto Scaling Group — 2 AZ
   ↓
Amazon RDS PostgreSQL Multi-AZ
```

Además crea la VPC, subredes públicas/privadas, Internet Gateway, NAT Gateway por AZ, Security Groups y una aplicación NGINX de prueba sobre Amazon Linux 2023.

## Requisitos

- Terraform `>= 1.8`
- AWS Provider `>= 6.51`
- Credenciales AWS configuradas localmente
- Permisos para VPC, EC2, ELB, Auto Scaling, RDS, CloudFront, WAF, IAM/EC2 networking, ACM y Route 53 si usas dominio propio

Comprueba tus credenciales:

```bash
aws sts get-caller-identity
```

## Despliegue rápido

Desde esta carpeta:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Al finalizar:

```bash
terraform output cloudfront_url
```

Abre esa URL en el navegador. La primera propagación de CloudFront/VPC Origin puede tardar varios minutos.

## Dominio propio — opcional

Por defecto no necesitas comprar ni configurar un dominio: Terraform entrega la URL estándar de CloudFront.

Si ya tienes una Hosted Zone en Route 53, edita `terraform.tfvars`:

```hcl
domain_name    = "app.example.com"
hosted_zone_id = "Z0123456789EXAMPLE"
```

Terraform solicitará un certificado ACM en `us-east-1`, creará la validación DNS y apuntará el dominio a CloudFront.

## Qué hace cada archivo

| Archivo | Función |
|---|---|
| `versions.tf` | Terraform, providers y alias `us-east-1` |
| `variables.tf` | Parámetros personalizables |
| `main.tf` | Toda la arquitectura AWS |
| `outputs.tf` | URLs, IDs y endpoints resultantes |
| `terraform.tfvars.example` | Ejemplo listo para copiar |

## Seguridad del ejemplo

El ALB es **interno** y su Security Group solo permite HTTP desde la managed prefix list `com.amazonaws.global.cloudfront.origin-facing`. La aplicación únicamente acepta tráfico desde el Security Group del ALB y RDS únicamente desde la capa de aplicación.

Las reglas administradas de AWS WAF comienzan en `COUNT` para evitar falsos positivos durante el rollout; la regla de rate limiting sí bloquea tráfico cuando supera el umbral configurado.

## Consideraciones de costo

Este laboratorio crea recursos facturables, incluidos **dos NAT Gateways, ALB, EC2, RDS Multi-AZ, CloudFront y WAF**. No lo dejes ejecutándose si solo estás probando.

Para eliminar todo:

```bash
terraform destroy
```

## Antes de usarlo como producción real

Este baseline está diseñado para aprender y demostrar el patrón completo. Antes de llevarlo a una carga empresarial deberías, como mínimo, mover secretos a AWS Secrets Manager, habilitar logging centralizado, ajustar WAF con tráfico real, definir estrategia de backups/restore, usar un backend remoto para Terraform state, activar controles de CI/CD y evaluar `deletion_protection` para recursos críticos.

> Código de referencia: **Juan Gutierrez · AWS Cloud Odyssey · 2026**
