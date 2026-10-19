# 08 · Observando la Nube: observabilidad operativa en AWS

**Autor:** Juan Gutierrez · AWS Cloud Odyssey · Arquitectura de producción

> La observabilidad no consiste en acumular logs. Consiste en detectar degradación, explicar su causa y recuperar el servicio antes de incumplir los objetivos del negocio.

## Contexto y requisitos

Una plataforma con ALB, Amazon EKS/EC2, Lambda y Amazon RDS necesita responder: ¿qué servicio falla?, ¿desde cuándo?, ¿qué clientes están afectados?, ¿qué cambió? Diseñamos para métricas, logs estructurados y trazas distribuidas, con objetivos SLO y responsables operativos.

**Objetivos de referencia (ajustables):** disponibilidad mensual 99,9 %, latencia p95 menor a 500 ms para una API crítica, tasa de errores 5xx menor a 1 % y alertas accionables. Los umbrales son ejemplos, no compromisos universales.

## Arquitectura

![Arquitectura de observabilidad en AWS](./49737de8-3541-4809-a9b2-a5e7f2c53a63.png)

*Diagrama conceptual. El PNG se incorpora al repositorio por separado; no considerar el enlace como evidencia de que el archivo exista.*

```text
Usuarios → ALB → EKS/EC2 → RDS
                  ↘ OpenTelemetry / instrumentación → métricas, logs, trazas
Lambda / API Gateway → CloudWatch Logs y métricas / AWS X-Ray
CloudWatch dashboards y alarmas → SNS → on-call / runbooks
```

**Flujo de señales:** CloudWatch recibe métricas de infraestructura y aplicación; CloudWatch Logs centraliza eventos estructurados; X-Ray u OpenTelemetry permiten seguir solicitudes entre servicios. Alarmas de CloudWatch notifican a SNS y pueden activar respuesta automatizada, con aprobación cuando exista riesgo.

## Decisiones y compromisos

| Decisión | Ventaja | Coste / riesgo |
|---|---|---|
| CloudWatch como plano operativo inicial | Integración nativa y menos componentes | Retención, ingestión y métricas personalizadas pueden elevar el gasto |
| OpenTelemetry para instrumentación | Portabilidad y correlación | Requiere gobernar atributos, muestreo y colectores |
| Alarmas sobre SLI/SLO y síntomas | Menos ruido para guardias | Exige conocer el comportamiento real del servicio |
| X-Ray / trazas distribuidas | Identifica latencia entre dependencias | El muestreo puede omitir eventos poco frecuentes |
| OpenSearch solo para búsqueda avanzada justificada | Análisis flexible | Operación y coste adicionales |

**Alternativa:** un stack Prometheus/Grafana administrado puede ser preferible para métricas de Kubernetes y PromQL. No duplicar indiscriminadamente todas las señales entre herramientas.

## Seguridad y privacidad

- Roles IAM de mínimo privilegio; separar lectura, configuración de alarmas y automatización de respuesta.
- Evitar credenciales, tokens, datos personales y payloads sensibles en logs. Aplicar filtrado en origen.
- Configurar retención explícita, cifrado en reposo y políticas de acceso; revisar requisitos de residencia de datos.
- Proteger endpoints de colectores y validar conectividad privada cuando corresponda.

## Resiliencia y respuesta

1. Alertar por síntomas (errores, latencia, saturación) y no por cada evento aislado.
2. Incluir en cada alarma servicio, entorno, SLO afectado, dashboard, propietario y runbook.
3. Durante incidentes: establecer impacto → consultar métricas → correlacionar logs por trace ID → inspeccionar trazas → comprobar despliegues recientes.
4. Probar fallos controlados, pérdida de dependencias, saturación y recuperación; verificar que la telemetría sobreviva al incidente.

## FinOps de observabilidad

Definir retención por categoría (por ejemplo 7/30/90 días según necesidad), limitar etiquetas de alta cardinalidad, muestrear trazas, filtrar eventos de poco valor y revisar mensualmente costos de ingesta, almacenamiento, consultas y métricas. **No** desactivar telemetría crítica solo para reducir costos.

## Terraform mínimo reproducible

El directorio [terraform](./terraform/) crea un log group con retención y una alarma para errores HTTP 5xx del ALB. Requiere un ARN suffix válido del ALB y un tópico SNS existente. No despliega EKS ni modifica cargas productivas.

```bash
cd terraform
terraform init
terraform validate
terraform plan -var='alb_arn_suffix=app/mi-alb/1234567890abcdef' -var='alarm_sns_topic_arn=arn:aws:sns:us-east-1:123456789012:ops-alerts'
```

**Precaución:** sustituir identificadores de ejemplo; validar el plan y permisos antes de aplicar. El umbral de 5xx debe adaptarse al tráfico; para bajo volumen considerar tasas y ventanas mayores.

## Checklist de producción

- [ ] SLI y SLO acordados con negocio
- [ ] IDs de correlación y logs JSON sin secretos
- [ ] Dashboards por servicio, entorno y experiencia de usuario
- [ ] Alarmas con dueño, severidad y runbook
- [ ] Prueba de notificación SNS y escalamiento
- [ ] Retención, cifrado, accesos y presupuesto definidos
- [ ] Simulacro de incidente y revisión posterior

## Referencias oficiales

- [Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html)
- [CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [CloudWatch Logs retention](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- [AWS X-Ray](https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html)
- [AWS Well-Architected Operational Excellence](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/welcome.html)

---

*Serie de arquitectura AWS en producción · Juan Gutierrez.*
