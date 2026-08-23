# ☁️ AWS Cloud Odyssey

### *Un viaje por arquitecturas AWS de producción*

Bienvenido a **AWS Cloud Odyssey**, una serie técnica en español dedicada al diseño de arquitecturas reales sobre Amazon Web Services.

Aquí no quiero limitarme solamente a explicar qué hace cada servicio. El objetivo es documentar **cómo pienso una arquitectura cuando la llevo a un escenario de producción**: qué requisito intento resolver, qué riesgo estoy aceptando, qué alternativa descartaría, qué impacto puede tener en operación y costos, y cómo convertir la decisión en infraestructura reproducible.

## 🧠 Perspectiva desde la experiencia

Esta serie nace de una idea sencilla: en proyectos reales, la arquitectura rara vez consiste en elegir el servicio correcto de una lista. Normalmente hay restricciones de red, seguridad, presupuesto, operación, equipos existentes y decisiones heredadas que obligan a evaluar **trade-offs**.

Por eso cada capítulo separará tres cosas:

- **lo que recomienda el patrón de referencia**, para entender una base sólida;
- **lo que yo decidiría como arquitecto**, explicando el porqué y las alternativas;
- **lo que validaría antes de producción**, porque un diagrama por sí solo no demuestra que una solución sea operable.

Cuando una decisión dependa del contexto, lo diré explícitamente. Cuando una opción incremente costo a cambio de resiliencia o seguridad, también. Y cuando el código sea un laboratorio o baseline y no una solución lista para cualquier empresa, quedará indicado.

La intención de **AWS Cloud Odyssey** es que cada arquitectura pueda defenderse en una conversación técnica: no solo mostrar *qué servicios aparecen*, sino explicar **por qué están ahí, qué problema resuelven y qué cambiaría bajo otras condiciones**.

## 🧭 La Odyssey

| Capítulo | Misión | Estado |
|---|---|---|
| **01** | 🌐 El Perímetro Global — Entrada segura a una aplicación AWS | 🚀 Publicado |
| **02** | 🏗️ Construyendo para Producción — Arquitectura Multi-AZ | Próximamente |
| **03** | ☸️ Kubernetes a Escala — Amazon EKS | Próximamente |
| **04** | 🛡️ Defensa en Profundidad — Seguridad AWS | Próximamente |
| **05** | ⚡ El Mundo Serverless | Próximamente |
| **06** | 🤖 La Era GenAI — Amazon Bedrock | Próximamente |
| **07** | 📊 El Camino de los Datos | Próximamente |
| **08** | 🔭 Observando la Nube | Próximamente |
| **09** | 💰 Arquitectura con FinOps | Próximamente |
| **10** | 🏢 La Organización Cloud | Próximamente |
| **11** | 🌎 Sobreviviendo a una Región | Próximamente |
| **12** | 🏆 La Arquitectura Final | Próximamente |

## 🚀 Comienza el viaje

### [Capítulo 01 — El Perímetro Global](./capitulos/01-el-perimetro-global/README.md)

Diseñaremos la entrada global de una aplicación AWS utilizando **Amazon Route 53, Amazon CloudFront, AWS WAF, Application Load Balancer y una capa de aplicación privada**. Además del patrón, el capítulo documenta decisiones, amenazas, costos, observabilidad, errores que evitaría y un baseline desplegable con Terraform.

---

**Juan Gutierrez** · AWS Cloud Odyssey · Arquitectura · Seguridad · Resiliencia · Escalabilidad · FinOps · Infrastructure as Code
