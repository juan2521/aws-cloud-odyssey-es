# Terraform — DNS de recuperación

Ejemplo mínimo: dos registros A de failover en una zona pública existente y health check HTTPS del primario. No crea infraestructura de aplicación ni promueve bases de datos. Sustituye las IP de documentación y la zona por valores reales. El secundario debe estar saludable y listo antes de conmutar.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='zone_id=Z123456789EXAMPLE' -var='record_name=app.example.com' -var='primary_ip=203.0.113.10' -var='secondary_ip=198.51.100.20' -var='health_fqdn=health.example.com'
```
