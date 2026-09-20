# ⚡ AWS Cloud Odyssey — Capítulo 05

# El Mundo Serverless — Arquitectura Event-Driven

### *Diseñando para picos, reintentos y fallas parciales sin convertir Lambda en un monolito distribuido*

**Autor:** Juan Gutierrez  
**Serie:** AWS Cloud Odyssey  
**Enfoque:** Arquitecturas AWS de producción

---

Serverless elimina servidores que administrar, no decisiones que tomar. El problema real aparece cuando una API que funcionaba bien con poco tráfico recibe un pico, una dependencia se ralentiza, un evento llega dos veces o un mensaje venenoso bloquea un lote. Mi diseño parte de esas condiciones, no del happy path.

> **Misión:** construir una plataforma transaccional event-driven donde el camino síncrono sea corto, el trabajo desacoplable sea asíncrono y cada fallo tenga una ruta explícita de recuperación.

## 🎯 Requisitos reales

- aceptar tráfico HTTP variable sin mantener capacidad ociosa;
- responder al cliente sin esperar procesos secundarios;
- absorber picos y backpressure;
- asumir entrega al menos una vez y diseñar consumidores idempotentes;
- aislar mensajes que no pueden procesarse;
- evitar credenciales estáticas y limitar permisos por función;
- tener trazabilidad desde request hasta evento y consumidor;
- controlar concurrencia para no derribar dependencias downstream;
- poder reprocesar fallos de forma segura;
- entender el costo por request, evento, transición y observabilidad.

---

## 🗺️ Arquitectura

<p align="center">
  <img src="./arquitectura/chapter-05-serverless-event-driven-architecture.png" alt="AWS Cloud Odyssey - Capítulo 05 - El Mundo Serverless - Diseñada por Juan Gutierrez" width="1200">
</p>

> **Imagen pendiente de carga manual:** `capitulos/05-el-mundo-serverless/arquitectura/chapter-05-serverless-event-driven-architecture.png`

La arquitectura separa dos caminos. El **camino síncrono** usa Amazon API Gateway, Lambda y DynamoDB para aceptar y persistir la intención rápidamente. El **camino asíncrono** publica eventos de dominio en EventBridge, enruta trabajo con SQS y ejecuta consumidores Lambda independientes. Step Functions aparece solo cuando existe un workflow que realmente necesita estado, compensación o decisiones visibles.

---

# 🧠 Decisión 01 — Mantener corto el camino síncrono

No encadeno cinco Lambdas detrás de una petición HTTP. Cada salto añade latencia, modos de falla y acoplamiento. Si el cliente solo necesita saber que su operación fue aceptada, persisto el estado mínimo y desacoplo efectos secundarios.

API Gateway aporta autenticación, throttling y contrato HTTP; Lambda ejecuta lógica; DynamoDB ofrece persistencia de baja operación. Para cargas con consultas relacionales complejas o transacciones SQL, Aurora Serverless v2 puede ser una mejor decisión: **serverless compute no obliga a usar una base NoSQL**.

**Trade-off:** responder `202 Accepted` mejora resiliencia y desacoplamiento, pero el cliente necesita consultar estado o recibir una notificación posterior. Para operaciones que requieren resultado inmediato mantengo el flujo síncrono, pero con un presupuesto explícito de latencia.

---

# 🧠 Decisión 02 — EventBridge enruta; SQS absorbe presión

EventBridge y SQS resuelven problemas distintos. Uso **EventBridge** cuando quiero distribuir eventos por reglas y permitir que nuevos consumidores aparezcan sin modificar al productor. Uso **SQS** delante de consumidores cuando necesito buffering, backpressure y control del ritmo de procesamiento.

No pongo una cola entre todos los componentes por dogma. Si el consumidor puede procesar directamente el evento y el patrón de fallos es simple, una integración directa puede reducir costo y complejidad.

**Trade-off:** más desacoplamiento mejora aislamiento, pero introduce consistencia eventual, observabilidad distribuida y operación de DLQs.

---

# 🧠 Decisión 03 — At-least-once cambia el diseño del negocio

En sistemas event-driven un evento puede procesarse más de una vez. Por eso una Lambda que cobra, reserva inventario o envía una orden no puede asumir “exactamente una ejecución”.

Uso una **idempotency key** estable —por ejemplo `orderId + operation`— y un registro condicional en DynamoDB con TTL. El segundo intento devuelve el resultado previo o se ignora según la operación. La idempotencia debe cubrir el efecto de negocio, no solamente el handler.

Para SQS habilito partial batch response cuando proceso lotes: un mensaje malo no debería obligar a reprocesar todos los buenos.

---

# 🧠 Decisión 04 — DLQ no significa recuperación

Cada cola crítica tiene redrive policy y DLQ, pero una DLQ sin alarma, owner y runbook solo es almacenamiento de errores.

Defino:

1. cuántos reintentos son razonables;
2. qué errores son transitorios y cuáles permanentes;
3. alarma por profundidad/edad de DLQ;
4. procedimiento de inspección y redrive;
5. protección contra reprocesar un efecto no idempotente.

La visibilidad de SQS se ajusta al tiempo real del consumidor. También limito concurrencia Lambda cuando un downstream —una API externa o base de datos— no escala al mismo ritmo que la cola.

---

# 🧠 Decisión 05 — Orquestación cuando el estado importa

Uso Step Functions cuando el proceso tiene pasos, timeouts, retries, ramas, compensaciones o espera y quiero que el estado sea visible. No lo uso para reemplazar tres líneas de código.

Para workflows largos o con auditoría de negocio prefiero una orquestación explícita. Para fan-out independiente, coreografía con eventos suele ser más simple. El criterio no es “qué servicio es más moderno”, sino **dónde quiero que viva el conocimiento del proceso**.

---

# 🔐 Seguridad

- API Gateway protegido con el mecanismo de identidad adecuado al consumidor; WAF cuando la exposición/riesgo lo justifica.
- Un execution role por función o responsabilidad, sin roles compartidos con permisos amplios.
- Secrets Manager/Parameter Store para secretos/configuración; nunca secretos en código.
- KMS cuando necesito control explícito de claves y políticas.
- Resource policies en EventBridge/SQS cuando existe integración cross-account.
- No coloco Lambda dentro de una VPC por costumbre: solo cuando necesita recursos privados o controles de red específicos.
- Valido payloads y autorizo la acción, no confío en que “vino de un servicio AWS”.

---

# 🧯 Resiliencia

Serverless no elimina límites. Diseño alrededor de concurrencia Lambda, cuotas de API Gateway/EventBridge, capacidad del downstream y tamaño/retención de mensajes.

La cola funciona como amortiguador, pero observo **edad del mensaje**, no solo cantidad. Un backlog estable puede ocultar que el negocio lleva 40 minutos de retraso. Para dependencias externas uso timeouts agresivos, retries con backoff/jitter y circuit-breaking cuando corresponda.

Si una operación necesita orden estricto o deduplicación de SQS, evalúo FIFO entendiendo su impacto en throughput y message groups. No selecciono FIFO solo porque “suena más seguro”.

---

# 🔭 Observabilidad

Correlaciono `requestId`, `correlationId` y el identificador de negocio a través de API, eventos y consumidores. Uso logs estructurados y métricas que representen experiencia, no solo infraestructura:

- latencia/error/throttling de API Gateway y Lambda;
- `Errors`, `Throttles`, `Duration` y concurrencia Lambda;
- edad y profundidad de SQS/DLQ;
- fallos de Step Functions;
- eventos descartados o fallidos;
- duración end-to-end de la transacción.

CloudWatch centraliza métricas/logs/alarmas y X-Ray/tracing ayuda cuando necesito seguir una transacción distribuida. Evito loggear payloads completos con PII por comodidad.

---

# 💰 Costos y FinOps

Serverless suele ser atractivo con demanda variable, pero no es automáticamente barato. Reviso:

- requests y transferencia de API Gateway;
- invocaciones, duración, memoria y arquitectura de Lambda;
- requests de SQS/EventBridge;
- lecturas/escrituras y almacenamiento de DynamoDB;
- transiciones de Step Functions;
- CloudWatch Logs, métricas custom y retención;
- NAT Gateway si una Lambda en VPC sale a Internet.

Optimizar memoria Lambda puede reducir duración y costo total. Antes de meter funciones en subnets privadas calculo el costo de NAT y evalúo endpoints privados. En tráfico alto y estable comparo contra ECS/Fargate o compute persistente: el modelo correcto depende de la curva de demanda y del costo operativo, no de una etiqueta “serverless”.

---

# ⚙️ Operación

- contratos de eventos versionados y compatibles hacia atrás;
- aliases/versions y despliegue gradual para funciones críticas;
- límites de reserved concurrency donde protegen dependencias;
- DLQ/redrive probado, no solo configurado;
- dashboards por journey de negocio;
- alarmas accionables con owner y runbook;
- pruebas de carga que incluyan burst, poison messages y downstream lento;
- IaC para colas, reglas, permisos y alarmas; nada crítico creado a mano.

---

# ⚠️ Errores comunes

- convertir una Lambda en un monolito con 30 responsabilidades;
- Lambda → Lambda → Lambda de forma síncrona;
- asumir exactly-once;
- crear DLQ sin alarma ni proceso de redrive;
- reintentar errores permanentes hasta agotar capacidad;
- dejar concurrencia ilimitada contra una base/API limitada;
- usar EventBridge cuando realmente se necesita buffering;
- usar SQS cuando realmente se necesita routing/fan-out flexible;
- meter toda Lambda en VPC “por seguridad”;
- registrar tokens, PII o payloads completos;
- ignorar el costo de observabilidad y NAT.

---

# 🧪 Qué valido antes de producción

- [ ] ¿El camino síncrono contiene solo lo que el usuario necesita esperar?
- [ ] ¿Cada evento tiene schema, owner, versión e identificador de correlación?
- [ ] ¿Los consumidores son idempotentes ante duplicados?
- [ ] ¿SQS visibility timeout y Lambda timeout son coherentes?
- [ ] ¿Partial batch response está habilitado donde corresponde?
- [ ] ¿Cada DLQ crítica tiene alarma, runbook y redrive probado?
- [ ] ¿Reserved concurrency protege dependencias limitadas?
- [ ] ¿Retries distinguen errores transitorios de permanentes?
- [ ] ¿Roles IAM aplican mínimo privilegio por función?
- [ ] ¿No hay secretos ni PII innecesaria en logs/eventos?
- [ ] ¿Dashboards muestran latencia end-to-end y edad de backlog?
- [ ] ¿Se probó burst, duplicado, poison message y caída downstream?
- [ ] ¿Se comparó el costo con una alternativa no serverless para la carga esperada?

---

# 🧱 Baseline Terraform

[`terraform/`](./terraform/) despliega un baseline deliberadamente pequeño: EventBridge custom bus → SQS → Lambda, DLQ, permisos mínimos y partial batch response. Es una base para practicar desacoplamiento e idempotencia; API, datastore de negocio y autenticación deben añadirse según el caso real.

---

# 🧭 Lección de arquitectura

Mi regla práctica es: **serverless funciona mejor cuando cada componente tiene una responsabilidad pequeña y el fallo es parte del contrato**. La pregunta no es “¿puedo hacerlo con Lambda?”, sino “¿qué pasa con el negocio cuando este evento llega dos veces, 20 minutos tarde o no puede procesarse?”.

Si la arquitectura no responde eso, todavía es una demo.

---

## 📚 Referencias oficiales

- AWS Lambda — Designing Lambda applications / event-driven architectures
- AWS Lambda — Best practices
- AWS Lambda + Amazon SQS — event source mappings and partial batch responses
- AWS Prescriptive Guidance — partial batch responses and DLQ patterns
- Amazon EventBridge — event-driven architectures
- AWS Step Functions — orchestration and EventBridge integration

---

**Juan Gutierrez**  
Solutions Architect · Cloud Architecture · Kubernetes · Security · FinOps · Cloud Modernization
