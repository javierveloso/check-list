# 10 · Observabilidad · Logs y métricas

> Logs estructurados, métricas operativas (RED/USE) y presupuestos de error.
>
> **Marcos de referencia:** Google SRE book · OpenTelemetry · RED method (Rate, Errors, Duration) · USE method (Utilization, Saturation, Errors).

---

## A. Logging

#### `OBS-LOG-001` — Logs estructurados (JSON) en producción
**Severidad:** high · **Aplica a:** backend · infra

Los logs se emiten como JSON con campos consistentes, no solo texto plano.

**Dónde buscar:** `**/logger*`, `**/logging/**`, `**/middleware/**`, `**/*.{ts,js,py,go,java}`, `package.json`, `requirements.txt`
**Patrones:**
- `console\.log\(`     # log no estructurado en JS/TS productivo
- `\bprint\(`     # print en código Python productivo
- `winston|pino|bunyan|loguru|structlog|logrus|zap`     # presencia de logger estructurado
- `logger\.(info|warn|error|debug)\([\"']\{`     # JSON inline (señal positiva)
- `format:\s*[\"']text[\"']|format:\s*[\"']plain[\"']`     # formato de texto plano configurado
**Señal de N/A:** no hay logger configurado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Formato JSON con campos: `timestamp` (ISO 8601 UTC), `level`, `message`, `service`, `environment`.
- [ ] Campos estándar de correlación: `request_id`, `trace_id`, `span_id`, `user_id` (pseudonimizado).
- [ ] El logger envuelve el framework para asegurar el formato.
- [ ] Logs de librerías de terceros se reformatean al formato común.

**Banderas rojas:**
- `print(...)` o `console.log` en productivo.
- Logs de texto libre no parseables.
- Formatos distintos por servicio que dificultan correlacionar.

---

#### `OBS-LOG-002` — Niveles usados correctamente
**Severidad:** medium · **Aplica a:** all

Cada evento va al nivel apropiado; el nivel de producción es INFO o superior.

**Dónde buscar:** `**/logger*`, `**/logging/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `logger\.(debug|info|warn|error|fatal)\(`     # uso explícito de niveles
- `level:\s*[\"'](debug|trace)[\"']`     # nivel debug/trace activo en config
- `LOG_LEVEL\s*=\s*[\"']?(DEBUG|TRACE)`     # variable de entorno con debug en prod
- `logger\([^.)]+\)`     # logger sin nivel (call directo)
- `for\s+.*:\s*\n\s*logger\.info`     # log dentro de loop (riesgo log-spam)
**Señal de N/A:** no hay logger configurado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] DEBUG: detalle solo útil en desarrollo.
- [ ] INFO: eventos operacionales relevantes (login, creación de recurso).
- [ ] WARN: condición anómala recuperable (retry, cache miss sospechoso).
- [ ] ERROR: fallo que merece atención (excepción no esperada).
- [ ] FATAL / CRITICAL: servicio no puede continuar.
- [ ] No hay "log-spam" (ej: un INFO por cada item procesado en un loop grande).

---

#### `OBS-LOG-003` — Contexto útil en cada log
**Severidad:** medium · **Aplica a:** backend

Los logs de una operación incluyen contexto suficiente para diagnosticar sin
reproducir.

**Dónde buscar:** `**/logger*`, `**/middleware/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `request[_-]?id|trace[_-]?id|correlation[_-]?id`     # IDs de correlación presentes
- `AsyncLocalStorage|contextvars|context\.WithValue`     # propagación de contexto
- `duration_ms|elapsed_ms|took_ms`     # medición de duración
- `tenant[_-]?id|user[_-]?id`     # IDs de dominio en logs
- `logger\.(info|error)\([\"'][^\"']+[\"']\s*\)`     # log sin contexto adicional
**Señal de N/A:** no hay logger configurado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Duration en ms para operaciones medibles.
- [ ] IDs relevantes (request_id, user_id, tenant_id, recurso_id).
- [ ] Tamaños de input/output cuando ayudan.
- [ ] Propagación de contexto entre capas (context vars, AsyncLocalStorage).

---

#### `OBS-LOG-004` — PII y secretos redactados
**Severidad:** critical · **Tags:** `cwe-532`, `privacy` · **Aplica a:** backend

Los logs no contienen contraseñas, tokens, API keys, ni PII innecesaria.

(Ver `SEC-CRYPTO-011`, `LLM-SEC-013`.)

**Dónde buscar:** `**/logger*`, `**/logging/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `log.*\.(password|token|secret|api[_-]?key|authorization)`     # secretos en log
- `logger\.\w+\([^)]*req\.body`     # body completo a log
- `logger\.\w+\([^)]*\.(email|phone|ssn|rut|dni)`     # PII a log
- `redact|sanitize|maskPII|scrub`     # capa de redacción (señal positiva)
- `JSON\.stringify\(req\)|JSON\.stringify\(user\)`     # serialización completa de objetos sensibles
**Señal de N/A:** no hay logger configurado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Capa de redacción en el logger (campos allowlist/blocklist).
- [ ] Errores de validación no reflejan el payload completo.
- [ ] Stack traces sin variables sensibles.
- [ ] Revisión periódica de logs en staging para detectar leaks.

---

#### `OBS-LOG-005` — Retención y agregación
**Severidad:** medium · **Aplica a:** infra

Los logs se envían a un backend centralizado con retención definida.

**Dónde buscar:** `**/*.{ts,js,py,go,java}`, `**/k8s/**`, `**/helm/**`, `docker-compose*.yml`, `**/*.{tf,yaml}`
**Patrones:**
- `elasticsearch|loki|datadog|cloudwatch|splunk|fluentd|fluent-bit|vector`     # backend de logs
- `retention[_-]?days|retention_in_days`     # retención configurada
- `log_group|log_stream|index_pattern`     # destino centralizado
- `stdout|stderr`     # log a stdout (idiomático para containers)
- `rotateFiles|maxFiles|maxSize`     # rotación local (anti-señal si es el único destino)
**Señal de N/A:** no hay logger configurado en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Stack de logs (Elastic, Loki, Datadog, CloudWatch) configurado.
- [ ] Retención alineada con necesidad operacional y política de datos.
- [ ] Búsqueda/filtrado por request_id y otros campos.
- [ ] Alertas sobre patrones en logs (ej: error spikes).

---

#### `OBS-LOG-006` — Errores no manejados capturados en frontend
**Severidad:** high · **Aplica a:** frontend

Errores no manejados en el frontend (render crashes, promesas rechazadas,
excepciones globales) se capturan, se muestran al usuario de forma amigable
y se envían a un sistema de observabilidad.

**Dónde buscar:** `**/main.{ts,tsx,js,jsx}`, `**/app.{ts,tsx,js,jsx}`, `**/*ErrorBoundary*`, `package.json`
**Patrones:**
- `@sentry/(react|browser|vue)|@datadog/browser-rum|applicationinsights-web`     # SDK frontend
- `addEventListener\([\"']error[\"']|addEventListener\([\"']unhandledrejection[\"']`     # listeners globales
- `ErrorBoundary|componentDidCatch|errorCaptured`     # boundary en framework
- `Sentry\.init|datadogRum\.init|appInsights\.loadAppInsights`     # inicialización
- `console\.error\(`     # único reporte de error (anti-señal)
- `sourcemaps?\s*[:=]\s*true|sentry-cli\s+sourcemaps`     # source maps subidos
**Señal de N/A:** stack_signal.has_frontend == false

**Verificar:**
- [ ] `window.addEventListener('error', handler)` y `window.addEventListener('unhandledrejection', handler)` registrados en el entrypoint (`main.tsx`, `main.ts`).
- [ ] Existe un `ErrorBoundary` global que envuelve toda la aplicación (React, Vue Error Handler, Angular `ErrorHandler`).
- [ ] El `ErrorBoundary` renderiza un fallback visual útil (no pantalla en blanco) con opción de "Reintentar".
- [ ] Los errores capturados se envían a un sistema de observabilidad (Sentry, Datadog RUM, Azure Application Insights).
- [ ] Source maps subidos al error tracker para simbolicación del stack en producción.
- [ ] PII redactada antes de enviar (nombres, emails, tokens no aparecen en el contexto del error).
- [ ] Sampling configurado para no superar cuota en picos de errores.

**Banderas rojas:**
- Ausencia de `ErrorBoundary` en el árbol de componentes raíz (`app.tsx`).
- `console.error` como único mecanismo de reporte de errores — invisible en producción.
- SDK de Sentry/Datadog no inicializado antes de `ReactDOM.createRoot` (errores tempranos se pierden).
- `window.onerror` sobrescrito a `null` o listener ausente en el entrypoint.

---

## B. Métricas RED / USE

#### `OBS-MET-001` — Métricas RED por endpoint/servicio
**Severidad:** high · **Aplica a:** backend · observability

Para cada endpoint crítico: **R**ate (req/s), **E**rrors (% 5xx), **D**uration
(latencia p50/p95/p99).

**Dónde buscar:** `**/middleware/**`, `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`, `package.json`, `requirements.txt`
**Patrones:**
- `prom-client|@opentelemetry/metrics|micrometer|statsd|datadog-metrics`     # SDK de métricas
- `http_requests_total|http_request_duration`     # métricas RED estándar
- `Histogram\(|Counter\(|new\s+Histogram|new\s+Counter`     # creación de métricas
- `/metrics|prometheus_handler|prom\.register`     # endpoint de exposición
- `route|method|status_code`     # labels RED
**Señal de N/A:** no hay backend / endpoints HTTP en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Histogramas de latencia exportados con labels (endpoint, status).
- [ ] Counters de requests y errores.
- [ ] Dashboards muestran RED por servicio.
- [ ] Alertas sobre desviaciones (error rate > umbral, latencia p95 > SLO).

**Ejemplos de métricas:** `http_requests_total{route,method,status}`, `http_request_duration_seconds` (histograma).

---

#### `OBS-MET-002` — Métricas USE en recursos
**Severidad:** medium · **Aplica a:** infra · observability

Para cada recurso (CPU, memoria, disco, pool de conexiones): Utilization,
Saturation, Errors.

**Dónde buscar:** `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`, `**/k8s/**`, `**/helm/**`, `**/*.{tf,yaml}`
**Patrones:**
- `node_exporter|cadvisor|process_cpu|process_memory`     # métricas de sistema
- `pool\.size|pool\.idle|pool\.active|max_connections`     # pool DB
- `queue_depth|queue_length|jobs_pending|jobs_active`     # cola de jobs
- `gauge\(|new\s+Gauge`     # gauges para utilization/saturation
- `cpu_usage|memory_usage|disk_usage`     # nombres de métricas USE
**Señal de N/A:** no hay infra/recursos gestionados en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Uso (%) y saturación (wait) medidos.
- [ ] Pool de BD: conexiones activas vs máximas.
- [ ] Pool de HTTP client: idle vs activas.
- [ ] Cola de background jobs: profundidad y latencia.

---

#### `OBS-MET-003` — Métricas de negocio
**Severidad:** medium · **Aplica a:** backend

Además de métricas técnicas, se miden eventos clave del negocio.

**Dónde buscar:** `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`, `**/analytics*`
**Patrones:**
- `track\(|trackEvent\(|analytics\.\w+\(`     # tracking de eventos negocio
- `Counter\([\"'](signup|login|conversion|payment)`     # contadores de negocio
- `mixpanel|amplitude|segment|posthog`     # SDK de producto
- `business_metric|kpi_|revenue_`     # naming convención de negocio
**Señal de N/A:** no hay backend / lógica de negocio en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Signups, logins, conversions, churn.
- [ ] Volumen por operación crítica (pagos, uploads, análisis).
- [ ] Trend dashboards visibles al equipo de producto.

---

#### `OBS-MET-004` — Cardinalidad controlada
**Severidad:** medium · **Aplica a:** observability

Los labels/tags de las métricas no explotan en cardinalidad (explota costo y
rompe store).

**Dónde buscar:** `**/instrumentation/**`, `**/*.{ts,js,py,go,java}`
**Patrones:**
- `labels:\s*\[[^\]]*user[_-]?id`     # user_id como label (anti-patrón)
- `labels:\s*\[[^\]]*request[_-]?id`     # request_id como label
- `labels:\s*\[[^\]]*uuid|email|session`     # alta cardinalidad
- `\.inc\([^)]*req\.url\)`     # URL cruda como label
- `normalizePath|routePattern|/users/:id`     # normalización (señal positiva)
**Señal de N/A:** no se exportan métricas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] No se usan user_id, request_id, UUIDs como label.
- [ ] Paths con parámetros normalizados (`/users/:id`, no `/users/abc-123`).
- [ ] Labels con valores acotados (enum, estados conocidos).

**Banderas rojas:**
- Labels con millones de valores distintos.
- Métricas que crecen sin cota.

---

## C. SLOs y presupuesto de error

#### `OBS-SLO-001` — SLOs definidos para servicios críticos
**Severidad:** medium · **Aplica a:** observability · product

Cada servicio/endpoint crítico tiene un SLO de disponibilidad y latencia.

**Dónde buscar:** `**/slo*`, `**/sli*`, `**/*.{yaml,yml,md}`
**Patrones:**
- *(sin patrones mecánicos — revisión humana / proceso)*
**Señal de N/A:** no hay backend / servicios productivos en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] SLO escrito: ej "99.9% de requests en < 500 ms" medido sobre ventana de 30d.
- [ ] Error budget calculado (1 - SLO).
- [ ] Dashboards muestran consumo del budget.
- [ ] Política clara sobre qué pasa cuando el budget se agota (freeze, revisión, etc.).

---

#### `OBS-SLO-002` — Alertas basadas en SLO (burn rate)
**Severidad:** medium · **Aplica a:** observability

Las alertas se disparan cuando el budget se consume demasiado rápido, no con
cada tick anómalo.

**Dónde buscar:** `**/alerts*.{yaml,yml,json}`, `**/*.alert.{yml,yaml}`, `**/prometheus/**`, `**/monitoring/**`
**Patrones:**
- `burn_rate|burnRate|burn-rate`     # alerta basada en burn rate
- `for:\s*\d+[hm]`     # ventanas multi-window de Prometheus
- `error_budget|errorBudget`     # presupuesto de error referenciado
- `pagerduty|opsgenie|victorops`     # integración con on-call
- `runbook_url|runbook:`     # link a runbook en alerta
**Señal de N/A:** no hay archivos de alertas en el repo o stack_signal.has_backend == false

**Verificar:**
- [ ] Multi-window burn rate alerts (ej: 2% budget en 1h OR 5% en 6h).
- [ ] Alertas van a canal accionable (PagerDuty, Opsgenie).
- [ ] Runbook linkeado desde la alerta.

---

## Checklist resumen

| ID             | Control                                            | Severidad |
| -------------- | -------------------------------------------------- | --------- |
| OBS-LOG-001    | Logs estructurados (JSON)                          | high      |
| OBS-LOG-002    | Niveles de log correctos                           | medium    |
| OBS-LOG-003    | Contexto útil                                      | medium    |
| OBS-LOG-004    | PII y secretos redactados                          | critical  |
| OBS-LOG-005    | Retención y agregación                             | medium    |
| OBS-LOG-006    | Logs frontend capturados                           | medium    |
| OBS-MET-001    | RED por endpoint/servicio                          | high      |
| OBS-MET-002    | USE en recursos                                    | medium    |
| OBS-MET-003    | Métricas de negocio                                | medium    |
| OBS-MET-004    | Cardinalidad controlada                            | medium    |
| OBS-SLO-001    | SLOs definidos                                     | medium    |
| OBS-SLO-002    | Alertas burn-rate                                  | medium    |
