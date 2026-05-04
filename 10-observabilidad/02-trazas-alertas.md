# 10 · Observabilidad · Trazas, alertas y health

> Tracing distribuido, correlation IDs, alertas accionables, health checks y
> runbooks.
>
> **Marcos de referencia:** OpenTelemetry · W3C Trace Context · Google SRE book.

---

## A. Tracing distribuido

#### `OBS-TRACE-001` — Tracing entre servicios con IDs propagados
**Severidad:** high · **Aplica a:** backend · observability

Las llamadas entre servicios (HTTP, gRPC, colas) propagan `trace_id` y `span_id`
siguiendo W3C Trace Context.

**Dónde buscar:** `**/instrumentation/**`, `**/middleware/**`, `**/*.{ts,js,py,go,java}`, `package.json`, `requirements.txt`
**Patrones:**
- `@opentelemetry|opentelemetry-sdk|opentelemetry-api`     # SDK OTel
- `jaeger|zipkin|datadog-trace|newrelic|applicationinsights`     # tracer alternativo
- `traceparent|tracestate|b3|x-cloud-trace-context`     # headers de propagación
- `trace\.context\.attach|propagation\.inject|propagation\.extract`     # propagación explícita
- `startSpan\(|withSpan\(|tracer\.startActiveSpan`     # creación de spans
**Señal de N/A:** no hay backend / llamadas entre servicios o stack_signal.has_backend == false

**Verificar:**
- [ ] SDK de OpenTelemetry (o equivalente) instrumentando entrada y salida.
- [ ] Headers `traceparent` y `tracestate` propagados.
- [ ] Colas: los mensajes llevan contexto de traza.
- [ ] Frontend inicia la traza cuando aplica (RUM → backend).

---

#### `OBS-TRACE-002` — Spans con atributos útiles
**Severidad:** medium · **Aplica a:** backend

Cada span tiene atributos que faciliten diagnóstico (método HTTP, status, query,
tamaño, errores).

**Dónde buscar:** `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `setAttribute\(|setAttributes\(|span\.set_attribute`     # atributos en span
- `http\.method|http\.status_code|http\.url|http\.route`     # atributos OTel HTTP
- `db\.statement|db\.system|db\.operation`     # atributos OTel DB
- `recordException|span\.record_exception`     # excepción registrada
- `addEvent\(|span\.add_event`     # eventos dentro del span
**Señal de N/A:** no hay tracing instrumentado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Spans incluyen: `http.method`, `http.status_code`, `http.url` (normalizada), `db.statement` (sanitizado), `error` (bool/message).
- [ ] Spans anidados reflejan la estructura de la llamada (child spans).
- [ ] Eventos (span events) marcan hitos internos.

---

#### `OBS-TRACE-003` — Muestreo inteligente
**Severidad:** medium · **Aplica a:** observability

No todas las trazas se guardan (costo); el muestreo preserva las interesantes
(errores, latencia alta).

**Dónde buscar:** `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`, `**/otel*.{yaml,yml}`, `**/collector*.{yaml,yml}`
**Patrones:**
- `TraceIdRatioBased|ParentBased|AlwaysOn|AlwaysOff`     # samplers OTel
- `sampling_rate|sample_rate|samplingProbability`     # configuración de tasa
- `tail_sampling|tailSampling`     # tail sampling activo
- `error_sampling|sample_on_error`     # forzar guardado en error
- `OTEL_TRACES_SAMPLER`     # variable de entorno OTel
**Señal de N/A:** no hay tracing instrumentado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Head sampling razonable (ej: 10% base).
- [ ] Tail sampling si es posible: se guardan todas las trazas con error o latencia > umbral.
- [ ] Configuración del sampler documentada.

---

#### `OBS-TRACE-004` — Correlación logs ↔ trazas
**Severidad:** high · **Aplica a:** backend · observability

Desde un log se puede saltar a la traza asociada, y viceversa.

**Dónde buscar:** `**/logger*`, `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `trace_id|trace\.id|traceId`     # trace_id incluido en log
- `span_id|span\.id|spanId`     # span_id incluido
- `getActiveSpan|trace\.get_current_span|currentSpan`     # extracción de contexto activo
- `LoggingInstrumentation|opentelemetry-instrumentation-logging`     # auto-instrumentación
- `logger\.\w+\([^)]*ctx\b`     # logger recibe contexto
**Señal de N/A:** no hay tracing instrumentado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Los logs incluyen `trace_id` y `span_id`.
- [ ] El backend de observabilidad permite navegar log → traza.
- [ ] `request_id` sobrevive cuando no hay traza distribuida.

---

## B. Request ID y correlación

#### `OBS-CORR-001` — Request-Id end-to-end
**Severidad:** high · **Aplica a:** backend · api · frontend

Cada request tiene un identificador único que atraviesa la app y aparece en
logs, métricas, trazas y respuestas.

**Dónde buscar:** `**/middleware/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `X-Request-Id|X-Correlation-Id|x-request-id`     # header estándar
- `request[_-]?id|correlation[_-]?id`     # variable interna
- `uuid|nanoid|crypto\.randomUUID`     # generación de ID
- `setHeader\([\"']X-Request-Id`     # eco en respuesta
- `req\.id\s*=|ctx\.requestId\s*=`     # asignación al contexto del request
**Señal de N/A:** no hay backend / endpoints HTTP en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] El servidor genera `X-Request-Id` si el cliente no lo envió (o respeta el del cliente).
- [ ] Aparece en headers de respuesta.
- [ ] El frontend lo loguea al reportar errores.
- [ ] Cuando un usuario reporta un problema, el support pide el Request-Id.

---

## C. Alertas

#### `OBS-ALERT-001` — Alertas accionables, no ruido
**Severidad:** high · **Aplica a:** observability

Cada alerta tiene un responsable claro, un runbook y es verificable.

**Dónde buscar:** `**/alerts*.{yaml,yml,json}`, `**/*.alert.{yml,yaml}`, `**/prometheus/**`, `**/monitoring/**`
**Patrones:**
- `runbook_url|runbook:|playbook:`     # link a runbook
- `severity:\s*(critical|high|warning|info)`     # severidad declarada
- `team:|owner:|service_owner:`     # ownership
- `summary:|description:|annotations:`     # campos descriptivos
- `expr:\s*[\"']?up\s*==\s*0[\"']?\s*$`     # alerta genérica sin contexto (anti-señal)
**Señal de N/A:** no hay archivos de alertas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Cada alerta documenta: qué significa, cómo validar, cómo mitigar.
- [ ] El mensaje de la alerta incluye **link directo al runbook** correspondiente (no requiere buscarlo manualmente a las 3 AM).
- [ ] Se mide el ratio de alertas accionables vs false positives.
- [ ] Alertas muy ruidosas se ajustan o retiran.
- [ ] Alert fatigue evitada (on-call health review).

**Banderas rojas:**
- Slack con cientos de alertas diarias que nadie revisa.
- Alertas sin runbook.

---

#### `OBS-ALERT-002` — Canales por severidad
**Severidad:** medium · **Aplica a:** observability

Alertas críticas van a on-call; informativas a canal no-bloqueante.

**Dónde buscar:** `**/alerts*.{yaml,yml,json}`, `**/alertmanager*.{yaml,yml}`, `**/monitoring/**`
**Patrones:**
- `pagerduty|opsgenie|victorops`     # canal on-call
- `slack|teams|webhook`     # canales no-urgentes
- `routes:|receiver:|match:`     # routing por severidad (alertmanager)
- `severity:\s*(critical|warning|info)`     # severidades distintas
- `escalation|escalate_after`     # escalation ladder
**Señal de N/A:** no hay archivos de alertas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Critical → PagerDuty/Opsgenie/phone call.
- [ ] High → Slack con mención al oncall.
- [ ] Info → canal de monitoreo no-urgente.
- [ ] Escalation ladder definido si no se reconoce la alerta.

---

#### `OBS-ALERT-003` — Alertas sobre síntomas, no causas
**Severidad:** medium · **Aplica a:** observability

Se alerta sobre lo que afecta al usuario (latencia alta, error rate), no sobre
cada métrica interna.

**Dónde buscar:** `**/alerts*.{yaml,yml,json}`, `**/*.alert.{yml,yaml}`, `**/prometheus/**`
**Patrones:**
- `error_rate|errorRate|http_requests.*5\d\d`     # alerta sobre síntoma user-facing
- `latency_p9[59]|histogram_quantile\(0\.9[59]`     # latencia percentil
- `slo|sli|burn_rate`     # alerta sobre SLO
- `cpu_usage|memory_usage|disk_usage`\s.*alert     # alerta puramente sobre causa (anti-señal si es la única)
**Señal de N/A:** no hay archivos de alertas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Alerta primaria: SLO burn / user-facing metrics.
- [ ] Alerta secundaria opcional: saturación de recursos (guía para investigar).
- [ ] No hay "alert per metric" genérico.

---

## D. Health checks

#### `OBS-HEALTH-001` — Liveness y readiness separados
**Severidad:** high · **Aplica a:** backend · infra

El servicio expone dos endpoints distintos: liveness (el proceso está vivo) y
readiness (está listo para atender tráfico).

**Dónde buscar:** `**/*.{ts,js,py,go,java}`, `**/k8s/**`, `**/helm/**`, `**/*.{yaml,yml}`
**Patrones:**
- `/healthz|/livez|/readyz|/health`     # endpoints estándar
- `livenessProbe|readinessProbe|startupProbe`     # probes K8s
- `app\.get\([\"']/(health|live|ready)`     # registro del endpoint
- `db\.ping\(\)|cache\.ping\(\)`     # verifica deps en readiness
- `return\s+\{\s*status:\s*[\"']ok[\"']\s*\}`     # health cosmético (anti-señal)
**Señal de N/A:** no hay backend / endpoints HTTP en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] `GET /healthz` / `/livez` liveness: respuesta rápida, no toca dependencias.
- [ ] `GET /readyz` readiness: valida BD, cache, deps críticas. Devuelve 503 si alguna no está lista.
- [ ] Orchestrator (K8s) usa ambos con timeouts apropiados.
- [ ] No se confunden: un DB caído hace readiness fail, pero no necesariamente liveness.

**Banderas rojas:**
- Endpoint `/health` que retorna `{ "status": "ok" }` sin verificar BD ni dependencias — devuelve 200 incluso cuando la app no puede procesar requests (health check cosmético).
- Liveness y readiness apuntan al mismo endpoint: un DB caído provoca reinicio del pod en lugar de sacarlo de rotación.
- Readiness no retorna `503` ante dependencia crítica caída — el load balancer sigue enviando tráfico.

---

#### `OBS-HEALTH-002` — Métricas de dependencias externas
**Severidad:** medium · **Aplica a:** backend · observability

Se miden tiempos y errores de las dependencias externas (BD, APIs terceros).

**Dónde buscar:** `**/instrumentation/**`, `**/middleware/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `dependency_duration|external_call_duration|upstream_latency`     # latencia por dep
- `circuit[_-]?breaker|opossum|resilience4j|hystrix`     # circuit breaker
- `axios\.interceptors|fetch.*wrapper|httpClient.*metrics`     # instrumentación de cliente HTTP
- `db\.query.*Histogram|prisma\.\$on\([\"']query`     # latencia DB instrumentada
- `dependency:|target:|upstream:`     # labels para identificar dep
**Señal de N/A:** no hay llamadas a dependencias externas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Latencia y error rate por dependencia.
- [ ] Alertas si una dependencia está degradada.
- [ ] Correlación entre dep down y afectación de endpoints.

---

## E. Runbooks y post-mortem

#### `OBS-RUN-001` — Runbooks para alertas críticas
**Severidad:** medium · **Aplica a:** observability · infra

Cada alerta crítica enlaza un runbook accionable.

**Dónde buscar:** `**/runbooks/**`, `**/docs/**`, `**/*.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / proceso)*
**Señal de N/A:** no hay backend / servicios productivos en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Runbooks versionados (repo/wiki).
- [ ] Incluyen: síntomas, diagnóstico, mitigación, escalation.
- [ ] Se revisan y actualizan tras cada incidente.

---

#### `OBS-RUN-002` — Post-mortem blameless tras incidentes
**Severidad:** medium · **Aplica a:** process

Cada incidente significativo produce un post-mortem con lecciones y acciones.

**Dónde buscar:** `**/postmortems/**`, `**/incidents/**`, `**/docs/**`, `**/*.md`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / proceso)*
**Señal de N/A:** no hay backend / servicios productivos en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Plantilla usada consistentemente.
- [ ] Acciones con dueño y fecha.
- [ ] Se comparten en el equipo.
- [ ] Cultura blameless (foco en sistemas, no personas).

---

## Checklist resumen

| ID              | Control                                            | Severidad |
| --------------- | -------------------------------------------------- | --------- |
| OBS-TRACE-001   | Tracing distribuido                                | high      |
| OBS-TRACE-002   | Spans con atributos                                | medium    |
| OBS-TRACE-003   | Muestreo inteligente                               | medium    |
| OBS-TRACE-004   | Logs ↔ trazas correlacionados                      | high      |
| OBS-CORR-001    | Request-Id end-to-end                              | high      |
| OBS-ALERT-001   | Alertas accionables                                | high      |
| OBS-ALERT-002   | Canales por severidad                              | medium    |
| OBS-ALERT-003   | Síntomas > causas                                  | medium    |
| OBS-HEALTH-001  | Liveness y readiness separados                     | high      |
| OBS-HEALTH-002  | Métricas de dependencias                           | medium    |
| OBS-RUN-001     | Runbooks                                           | medium    |
| OBS-RUN-002     | Post-mortem blameless                              | medium    |
