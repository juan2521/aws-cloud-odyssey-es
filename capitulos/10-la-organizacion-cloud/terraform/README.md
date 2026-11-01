# Terraform · guardrail de AWS Organizations (capítulo 10)

Este ejemplo crea **una SCP de demostración sin adjuntarla a ninguna OU**. Bloquea acciones de detención o eliminación de registros de AWS CloudTrail y AWS Config **solo si posteriormente se adjunta** a una OU de cuentas miembro. No instala AWS Control Tower, no crea cuentas y no cambia políticas efectivas por defecto.

## Prerrequisitos

- Terraform >= 1.5 y AWS provider compatible.
- Organización de AWS Organizations con **todas las funciones** y tipo **SERVICE_CONTROL_POLICY** habilitado.
- Credenciales de la cuenta de administración o un rol autorizado para gestionar políticas de Organizations; verificar el alcance de la delegación.
- Cuenta/OU de laboratorio y procedimiento de reversión antes de considerar un attachment.

## Validación segura

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

El plan por defecto debe mostrar la creación de **una política sin attachment**. Revisar el plan, el identificador de organización y el rol AWS antes de cualquier `apply`.

### Attachment opcional, solo con aprobación

```bash
terraform plan -var='attach_policy=true' -var='target_ou_id=ou-xxxx-xxxxxxxx'
# Sustituir por OU real de laboratorio; aprobar el plan y recién después considerar apply.
```

**Advertencias:** una SCP es un límite de permisos, **no concede acceso**; no se aplica a la cuenta de administración ni restringe roles vinculados a servicios de la misma forma que a identidades normales. Esta denegación puede bloquear operaciones legítimas de mantenimiento, enrolamiento o cambios de baseline. Probar con cuentas de laboratorio y revisar los controles administrados por Control Tower. No ejecutar `terraform destroy` sobre un estado compartido.

**Referencias:** [SCP de AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) · [Terraform aws_organizations_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) · [Terraform aws_organizations_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment)
