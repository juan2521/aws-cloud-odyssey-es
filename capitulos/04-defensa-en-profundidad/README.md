# 🛡️ AWS Cloud Odyssey — Capítulo 04

# Defensa en Profundidad — Seguridad AWS

### *Diseñando para que un control que falle no se convierta en un incidente completo*

**Autor:** Juan Gutierrez  
**Serie:** AWS Cloud Odyssey  
**Enfoque:** Arquitecturas AWS de producción

---

La seguridad real no consiste en poner un WAF delante de una aplicación y declarar el problema resuelto. En producción asumo que una credencial puede filtrarse, una regla puede quedar demasiado abierta, una dependencia puede tener una vulnerabilidad y un operador puede equivocarse. La arquitectura debe limitar qué puede ocurrir después.

> **Misión:** construir capas independientes de prevención, detección y respuesta para que comprometer una capa no entregue automáticamente identidad, red, datos y control administrativo.

## 🎯 Requisitos reales

- separar workloads, seguridad, logs y red mediante cuentas con responsabilidades distintas;
- acceso humano federado con MFA y privilegio mínimo;
- credenciales temporales para workloads, no access keys embebidas;
- proteger el edge y reducir exposición directa de orígenes;
- segmentar tráfico north-south y east-west según riesgo;
- cifrar datos y secretos con ownership y rotación definidos;
- centralizar evidencia fuera de la cuenta del workload;
- detectar amenazas, vulnerabilidades y drift de configuración;
- automatizar respuestas de bajo riesgo sin convertir una falsa alarma en una caída;
- conservar capacidad de investigación después de un compromiso.

---

## 🗺️ Arquitectura

<p align="center">
  <img src="./arquitectura/chapter-04-defense-in-depth-architecture.png" alt="AWS Cloud Odyssey - Capítulo 04 - Defensa en Profundidad - Diseñada por Juan Gutierrez" width="1200">
</p>

> **Imagen pendiente de carga manual:** `capitulos/04-defensa-en-profundidad/arquitectura/chapter-04-defense-in-depth-architecture.png`

La referencia visual separa cuentas de Workload, Security Tooling, Log Archive y Network/Shared Services. El tráfico web atraviesa Route 53, CloudFront, WAF y el balanceador; la inspección de red se centraliza solo cuando el modelo de riesgo lo justifica. GuardDuty, Inspector y Security Hub concentran detección, mientras CloudTrail, Config, VPC Flow Logs y logs de aplicación terminan en una cuenta de archivo independiente.

---

# 🧠 Decisión 01 — Separar el plano de seguridad del workload

No quiero que el administrador de una aplicación pueda borrar también la evidencia que explica qué ocurrió. Por eso uso AWS Organizations y cuentas dedicadas: **Security Tooling** para administración delegada de servicios de seguridad y **Log Archive** para retención central.

Security Hub, GuardDuty e Inspector se administran a nivel organizacional desde la cuenta delegada. La cuenta de administración de Organizations se reserva para tareas que realmente la requieren.

**Trade-off:** más cuentas implican más gobierno, pipelines y troubleshooting cross-account. A cambio obtenemos separación de funciones y un blast radius administrativo mucho menor.

---

# 🧠 Decisión 02 — Identidad primero; red después

Una VPN o una subnet privada no convierten una identidad privilegiada en segura. Para humanos parto de IAM Identity Center, MFA y permission sets por función. Para workloads uso roles con credenciales temporales y políticas acotadas.

Los permisos de emergencia son explícitos, auditados y temporales. No dejo usuarios IAM con access keys como mecanismo cotidiano de operación.

**Alternativa:** roles IAM federados directamente pueden funcionar en organizaciones pequeñas. Identity Center gana consistencia y ciclo de vida centralizado cuando aumentan cuentas y equipos.

---

# 🧠 Decisión 03 — El edge filtra ataques de aplicación; no reemplaza seguridad interna

CloudFront + AWS WAF reduce exposición y permite reglas administradas, rate-based rules y controles específicos del aplicativo. Shield Standard aporta protección DDoS base; Shield Advanced lo considero cuando el riesgo, criticidad y costo de indisponibilidad justifican capacidades adicionales.

No duplico reglas por costumbre. Cada regla WAF necesita propietario, métrica, pruebas y criterio de rollback. Antes de bloquear una nueva regla administrada prefiero observar en `COUNT`, revisar falsos positivos y después aplicar enforcement.

**Trade-off:** inspección más agresiva reduce superficie, pero puede bloquear clientes válidos. Seguridad que no puede explicar por qué bloqueó una transacción se vuelve deuda operacional.

---

# 🧠 Decisión 04 — Inspección centralizada solo con rutas diseñadas para ella

En entornos multi-VPC, Transit Gateway y AWS Network Firewall permiten centralizar inspección east-west, egress y tráfico híbrido. El punto difícil no es crear el firewall: es garantizar **simetría de flujo**, tablas de rutas correctas y dominios de falla por AZ.

No envío todo el tráfico a un firewall simplemente porque existe. Security Groups siguen siendo el control stateful cercano al workload. Network Firewall se reserva para necesidades de inspección, control de egress, firmas o segmentación que no resuelvo adecuadamente con SG/NACL.

**Trade-off:** centralizar políticas mejora consistencia, pero añade costo por procesamiento, Transit Gateway, transferencia y una dependencia operacional crítica. Para entornos pequeños, controles distribuidos pueden ser más simples.

---

# 🧠 Decisión 05 — La evidencia sale de la cuenta que produce el evento

CloudTrail organizacional, AWS Config, VPC Flow Logs y logs relevantes se centralizan. El bucket de archivo usa cifrado, versionado, lifecycle y permisos que impiden a operadores de workloads alterar la retención.

No recolecto logs “por si acaso”. Defino qué pregunta forense responde cada fuente y cuánto tiempo vale conservarla. CloudTrail responde actividad de API; Flow Logs ayuda con patrones de red; Config reconstruye cambios de configuración; logs de aplicación explican comportamiento funcional.

---

# 🛡️ Controles por capa

| Capa | Controles principales | Qué limita |
|---|---|---|
| Organización | Organizations, SCPs, cuentas separadas | acciones que una cuenta miembro no debe poder ejecutar |
| Identidad | Identity Center, MFA, IAM roles, Access Analyzer | abuso de credenciales y privilegios excesivos |
| Edge | CloudFront, WAF, Shield | ataques HTTP, floods y exposición directa |
| Red | SG, NACL, TGW, Network Firewall | movimiento lateral y egress no autorizado |
| Workload | hardening, patching, Inspector, runtime controls | explotación de hosts/imágenes/paquetes |
| Datos | KMS, Secrets Manager, políticas de recurso | acceso o exposición de datos/secretos |
| Detección | GuardDuty, Security Hub, Config, CloudTrail | tiempo hasta descubrir comportamiento anómalo |
| Respuesta | EventBridge, Lambda/SSM, SNS/ITSM | tiempo hasta contener un incidente |

---

# 🧯 Resiliencia y seguridad no son objetivos separados

Un firewall central de una sola AZ puede ser un control de seguridad y al mismo tiempo un punto único de falla. Los endpoints de inspección, NAT, balanceadores y rutas se diseñan por AZ. También pruebo qué ocurre si una automatización de seguridad revoca una policy, aísla una instancia o bloquea tráfico válido.

Para datos críticos, backup y recuperación tienen controles de acceso separados del workload. Un ransomware con permisos administrativos no debería poder destruir producción **y** todas sus copias recuperables.

---

# 🔭 Observabilidad y respuesta

Security Hub funciona como plano de agregación/priorización, no como sustituto del análisis. Correlaciono findings con contexto de activo, exposición y criticidad. GuardDuty aporta detección de amenazas; Inspector vulnerabilidades; Config postura/configuración; CloudTrail actividad de API.

EventBridge puede disparar automatizaciones, pero separo respuestas:

1. **Automáticas y reversibles:** etiquetar, crear ticket, enriquecer finding, bloquear un indicador muy confiable.
2. **Automáticas con guardrails:** aislar una instancia o revocar una sesión bajo condiciones verificadas.
3. **Human-in-the-loop:** acciones con alto blast radius o impacto comercial.

Mido MTTD, MTTR, findings críticos abiertos, cobertura de cuentas/regiones, tiempo de parcheo y porcentaje de recursos sin logging esperado.

---

# 💰 Costos y FinOps de seguridad

La seguridad tiene costo de inspección y también costo de telemetría. Reviso:

- WAF: Web ACL, reglas y requests inspeccionados;
- Network Firewall: endpoints, GB procesados y arquitectura de egress;
- Transit Gateway y transferencia inter-AZ;
- GuardDuty, Inspector y Security Hub según cobertura/uso;
- Config recording/evaluations;
- CloudTrail data events cuando se habilitan masivamente;
- CloudWatch/S3: ingestión, almacenamiento y retención.

Guardar todo para siempre no es una estrategia. Clasifico fuentes por valor forense/compliance y aplico lifecycle. Tampoco desactivo detección crítica solo porque genera costo: primero reduzco ruido, alcance innecesario y duplicación.

---

# ⚙️ Operación

- controles y reglas versionados como código;
- cambios WAF/firewall primero en observación cuando sea posible;
- runbooks de credencial comprometida, host comprometido y exposición pública;
- revisión periódica de permission sets, roles y excepciones;
- owners para findings y SLAs por severidad;
- simulacros/tabletops y pruebas de restauración;
- excepciones con fecha de expiración, no permanentes;
- break-glass probado y monitorizado.

---

# ⚠️ Errores comunes

- creer que “privado” significa “seguro”;
- usar el mismo administrador en todas las cuentas;
- dar `AdministratorAccess` a pipelines para ahorrar tiempo;
- permitir que la cuenta del workload borre sus logs centrales;
- desplegar Network Firewall sin validar rutas de retorno/simetría;
- activar cientos de reglas WAF directamente en bloqueo;
- cifrar con KMS pero dejar políticas de acceso excesivas;
- almacenar secretos en variables de Terraform, user data o repositorios;
- habilitar herramientas de detección sin proceso para atender findings;
- automatizar aislamiento sin mecanismo de rollback.

---

# 🧪 Qué valido antes de producción

- [ ] ¿Security Tooling y Log Archive están separados de workloads?
- [ ] ¿El acceso humano es federado, con MFA y mínimo privilegio?
- [ ] ¿Workloads usan roles temporales y no claves estáticas?
- [ ] ¿SCPs bloquean acciones realmente prohibidas sin romper recuperación?
- [ ] ¿WAF fue probado contra tráfico real y tiene métricas/rollback?
- [ ] ¿El origen solo acepta el tráfico que necesita?
- [ ] ¿Las rutas de inspección son simétricas y Multi-AZ?
- [ ] ¿SG/NACL/firewall reflejan flujos documentados?
- [ ] ¿CloudTrail/Config/Flow Logs llegan a almacenamiento central protegido?
- [ ] ¿GuardDuty/Inspector/Security Hub cubren cuentas y regiones objetivo?
- [ ] ¿Cada finding crítico tiene owner, SLA y ruta de escalación?
- [ ] ¿Automatizaciones de respuesta son reversibles o tienen aprobación?
- [ ] ¿Backups y claves tienen separación suficiente ante compromiso administrativo?
- [ ] ¿Se probó recuperación y respuesta, no solo configuración?

---

# 🧱 Baseline Terraform

El directorio [`terraform/`](./terraform/) contiene un baseline pequeño y desplegable para una capa de detección: CloudTrail con bucket cifrado/versionado y GuardDuty. Deliberadamente no intenta crear una landing zone completa ni un firewall central sin conocer CIDRs y rutas reales.

La decisión práctica es importante: **IaC útil no significa IaC gigante**. Un módulo de seguridad debe ser verificable, tener ownership claro y no esconder decisiones de red detrás de defaults.

---

# 🧭 Lección de arquitectura

Defensa en profundidad no significa comprar ocho servicios de seguridad. Significa diseñar controles que fallen de forma independiente y dejar suficiente evidencia para detectar qué capa cedió.

Mi prueba mental es esta: **si mañana una credencial de aplicación queda comprometida, ¿qué otra decisión tendría que fallar para que el atacante llegue a datos críticos, borre evidencia y permanezca sin ser detectado?** Si la respuesta es “ninguna”, todavía no existe defensa en profundidad.

---

## 📚 Referencias oficiales

- AWS Security Reference Architecture — Security Tooling account
- AWS Security Hub — Organizations and delegated administration
- AWS WAF / Shield — DDoS and application-layer protections
- Building a Scalable and Secure Multi-VPC AWS Network Infrastructure
- AWS Network Firewall — centralized inspection patterns
- AWS CloudTrail — organization trails
- Amazon GuardDuty — multi-account management
- Amazon Inspector — multi-account management

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization
