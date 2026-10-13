# 📊 AWS Cloud Odyssey — Capítulo 07

# El Camino de los Datos — Arquitectura de analítica gobernada en AWS

### *De archivos y eventos dispersos a información confiable, trazable y operable*

**Autor:** Juan Gutierrez  
**Serie:** AWS Cloud Odyssey  
**Enfoque:** Arquitecturas AWS de producción

---

Un data lake no es una colección de buckets. He visto que el riesgo real no es almacenar terabytes: es entregar resultados incorrectos porque un esquema cambió, repetir registros durante un reproceso, conceder permisos excesivos o descubrir demasiado tarde que las consultas escanean todos los archivos. Diseñaría primero la calidad, la propiedad de los datos y el mecanismo de recuperación; después elegiría los servicios.

> **Misión:** construir una plataforma de ingestión batch y streaming con zona raw recuperable, transformación validada, zona curated, catálogo y permisos gobernados, consultas con costo controlado y procedimientos de operación claros.

## 🎯 Requisitos reales

- Ingesta batch de CSV/JSON y eventos continuos sin acoplar productores a consumidores.
- Retención raw para reprocesamiento, controles de calidad, cuarentena y linaje.
- Consultas SQL ad hoc sobre datasets curados; warehouse solo cuando el patrón de uso lo justifique.
- Separación entre cuentas/equipos y acceso por dataset, tabla y columna.
- RPO/RTO y frescura acordados por dataset; alertas antes de que los consumidores detecten datos viejos.
- Control del costo de almacenamiento, ETL, streaming y bytes escaneados.
- Versionado de infraestructura, esquemas y transformaciones; trazabilidad de cada ejecución.

## 🗺️ Arquitectura

![Capítulo 07 — El Camino de los Datos — Arquitectura AWS por Juan Gutierrez](./Arquitectura%20moderna%20del%20lago%20de%20datos%20en%20AWS.png)

**Flujo:** productores batch → S3 raw; productores de eventos → Kinesis Data Streams → consumidor de aterrizaje en S3 raw; AWS Glue valida, transforma y envía registros inválidos a S3 quarantine; S3 curated en Parquet → Glue Data Catalog + Lake Formation → Athena y, cuando sea necesario, Redshift. CloudWatch y CloudTrail permiten observar operación y cambios. **El esquema es una referencia, no significa que todos los componentes deban desplegarse desde el primer día.**

---

## 🧠 Decisión 01 — Raw es la capacidad de recuperar, no el destino de consulta

Mantengo archivos originales en S3 con prefijos por origen y fecha de ingestión, cifrado, versionado según necesidad y controles de escritura. Un lote tiene identificador, checksum y metadatos de procedencia. Evito que analistas consulten raw directamente: puede contener PII, errores de esquema o registros incompletos.

**Alternativa:** transformar antes de aterrizar. Reduce almacenamiento temporal, pero elimina la fuente confiable para reproducir errores y volver a ejecutar cuando cambien reglas. Raw no es literalmente inmutable por defecto: si se exige WORM debo evaluar S3 Object Lock, retención y requisitos regulatorios.

## 🧠 Decisión 02 — Streaming cuando la frescura lo exige

Kinesis Data Streams desacopla productores y consumidores y ofrece retención configurable para replay dentro de la ventana contratada. Un consumidor de aterrizaje persiste los eventos en S3. La entrega y los reintentos pueden producir duplicados: uso event ID, deduplicación y checkpoints; no prometo exactamente una vez de extremo a extremo.

**Alternativa:** ingesta batch por intervalos o entrega administrada hacia S3. Si el SLA admite 15–60 minutos, no mantendría un pipeline streaming por moda. Streaming aporta latencia baja, pero también shards/capacidad, lag, orden por clave, backpressure y operación continua.

## 🧠 Decisión 03 — Curated significa contrato, no carpeta

AWS Glue ejecuta transformaciones idempotentes, valida tipos, obligatoriedad, unicidad y rangos, separa inválidos en quarantine y escribe Parquet comprimido. Defino particiones por columnas con cardinalidad razonable, no por identificador único. Compacto archivos pequeños y publico un manifiesto/versión de dataset después de una ejecución válida para evitar lecturas de datos parciales.

**Alternativa:** SQL ELT con Athena o Redshift para cargas sencillas. Glue/Spark solo compensa si la complejidad y volumen lo justifican. Parquet reduce lecturas para consultas columnares, pero no sustituye diseño de particiones ni estadísticas.

## 🧠 Decisión 04 — Gobierno aplicado, no solo documentado

Glue Data Catalog mantiene metadatos; Lake Formation puede centralizar permisos finos sobre tablas y columnas, con controles adicionales según el motor y la integración. Valido explícitamente que las ubicaciones S3 estén registradas y que los permisos IAM/S3 no permitan rutas de bypass. Etiquetas de clasificación, propietarios y políticas de retención forman parte del contrato de datos.

**Trade-off:** Lake Formation añade gobernanza y auditoría, pero también complejidad de grants, roles y troubleshooting. No confundo catálogo con control de acceso ni asumo que todas las herramientas aplican idénticamente las mismas políticas.

## 🧠 Decisión 05 — Athena primero, Redshift cuando haya razones

Athena permite SQL serverless directamente sobre datos curados en S3, con workgroups, límites de escaneo y resultados cifrados. Redshift tiene sentido para modelos dimensionales, concurrencia predecible, transformaciones SQL sostenidas o necesidades de rendimiento que las pruebas demuestren. No duplicaría todos los datasets en un warehouse por defecto.

**Trade-off:** Athena minimiza operación pero el costo y latencia dependen de bytes escaneados, formato y frecuencia; Redshift puede dar rendimiento sostenido a cambio de capacidad/administración y nuevos costos.

## 🔐 Seguridad

- IAM de mínimo privilegio para productores, Glue y consumidores; roles temporales y segregación de ambientes.
- S3 Block Public Access, TLS, cifrado SSE-KMS cuando se requiera control de claves, políticas de bucket y acceso privado.
- Lake Formation y permisos del catálogo para datasets gobernados; revisar acceso directo a S3 y credenciales fuera de banda.
- Datos sensibles clasificados, tokenizados o enmascarados antes de curated; secretos fuera de código.
- CloudTrail para auditoría API; habilitar eventos de datos S3 selectivamente según riesgo y costo.
- Política explícita de retención, borrado y acceso a raw/quarantine.

## 🧯 Resiliencia y consistencia

S3 raw permite reconstruir curated. Cada job registra `run_id`, watermark, versión de esquema, conteos de entrada/salida/rechazos y checksum cuando aplique. Reintentos acotados no deben duplicar resultados; diseño escrituras con staging y publicación controlada. Para streaming vigilo edad del último evento procesado, retraso del consumidor y retención disponible. La replicación entre regiones no es automática: solo la incorporaría tras definir recuperación y residencia.

## 🔭 Observabilidad

Dashboard por dataset: frescura, completitud, registros rechazados, duración/costo de Glue, errores, volumen raw/curated, lag de Kinesis, consultas Athena fallidas y bytes escaneados. Alarmas sobre umbrales de negocio, no solo fallos de infraestructura. CloudWatch centraliza métricas/logs; CloudTrail aporta auditoría; los logs deben evitar valores sensibles.

## 💰 FinOps

Costo total = S3 (capacidad, requests, lifecycle), Kinesis (capacidad/retención), Glue (tiempo de cómputo), catálogo/gobierno, Athena (bytes escaneados), Redshift si aplica, KMS, logs y transferencias. Parquet, compresión, particionado razonable y compactación suelen dar más ahorro que microoptimizar código. Defino presupuesto por dominio, etiquetas y alertas; mido costo por GB procesado y consulta útil.

## ⚙️ Operación y decisiones prácticas

Cada dataset necesita propietario, esquema, SLA de frescura, regla de calidad, política de retención y runbook. Un cambio incompatible de esquema debe fallar en cuarentena o versionarse, nunca propagarse silenciosamente. Reprocesar requiere ventana y procedimiento para evitar pisar datos publicados. Automatizo despliegues con Terraform y pruebas de transformación, pero separo infraestructura de permisos de negocio que necesitan revisión.

## ⚠️ Errores comunes

- Usar raw como capa de BI; confundir «está en S3» con «está gobernado».
- Particionar por ID único y generar millones de archivos diminutos.
- No controlar duplicados, reintentos ni eventos tardíos.
- Asumir que Lake Formation elimina por sí solo todo acceso directo a S3.
- No definir calidad, propietario ni freshness; confiar únicamente en el estado SUCCESS de Glue.
- Activar streaming, Redshift y todos los servicios sin justificar el SLA.
- Olvidar costos de CloudTrail data events, consultas repetidas y logs.

## 🧪 Validar antes de producción

- [ ] ¿Se puede reproducir curated desde raw con resultados consistentes?
- [ ] ¿Un registro duplicado o fuera de orden no altera métricas de negocio?
- [ ] ¿La falla parcial deja quarantine y no publica datos incompletos?
- [ ] ¿Un consumidor no autorizado recibe AccessDenied tanto vía Athena como vía S3 directo?
- [ ] ¿Frescura y completitud tienen SLO, dashboard, alarma y responsable?
- [ ] ¿La retención de Kinesis alcanza para recuperar el peor incidente previsto?
- [ ] ¿Parquet, particiones y tamaño de archivos reducen el escaneo medido?
- [ ] ¿Existen presupuesto, cuotas, lifecycle y pruebas de carga?
- [ ] ¿Se han probado restauración, rollback de esquema y borrado regulatorio?

## 🧱 Infrastructure as Code — Terraform

El baseline en [terraform/](./terraform/) despliega buckets separados raw/curated/quarantine, versionado, cifrado y bloqueo público, un stream Kinesis, Glue Data Catalog y un workgroup Athena con límite de escaneo. **Es una base de infraestructura, no un ETL productivo completo:** conectar productores, trabajos Glue, roles, Lake Formation grants y alarmas requiere el diseño específico del dominio.

### Guía oficial para validación

- [AWS Lake Formation — permisos y gobierno](https://docs.aws.amazon.com/lake-formation/latest/dg/what-is-lake-formation.html)
- [Amazon Athena — formatos columnares](https://docs.aws.amazon.com/athena/latest/ug/columnar-storage.html)
- [AWS Glue — Data Quality](https://docs.aws.amazon.com/glue/latest/dg/glue-data-quality.html)
- [Kinesis Data Streams — conceptos](https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html)

---

**Juan Gutierrez** · AWS Cloud Odyssey · Arquitectura · Seguridad · Datos · Resiliencia · FinOps
