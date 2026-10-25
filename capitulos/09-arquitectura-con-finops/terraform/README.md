# Terraform · presupuesto mensual FinOps

Ejemplo mínimo y deliberadamente no destructivo: crea **un presupuesto mensual de costos AWS** con notificaciones por correo al superar el 80 % del gasto real o el 100 % del gasto previsto. No crea cargas de trabajo, no compra Savings Plans y **no detiene recursos ni garantiza un límite de gasto**.

## Requisitos

- Terraform >= 1.5, credenciales AWS configuradas y permisos para gestionar AWS Budgets en la cuenta seleccionada.
- Correo de alertas válido y autorización para crear un presupuesto en esa cuenta.
- Revisar los costos de AWS Budgets según los límites y condiciones vigentes.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='alert_email=finops@example.com' -var='monthly_budget_usd=1000'
# Solo tras revisar el plan y sustituir el correo de ejemplo:
terraform apply -var='alert_email=finops@example.com' -var='monthly_budget_usd=1000'
```

**Importante:** no ejecutes `apply` con el correo de ejemplo. AWS Budgets no opera en tiempo real: puede existir demora entre el consumo y la alerta. Para eliminar solo este recurso de demostración, revisar primero `terraform plan -destroy`. No ejecutar `destroy` si el estado incluye recursos ajenos.

[Documentación AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) · [Recurso Terraform aws_budgets_budget](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget)
