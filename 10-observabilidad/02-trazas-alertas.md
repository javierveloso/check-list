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

**Verificar:**
- [ ] Spans incluyen: `http.method`, `http.status_code`, `http.url` (normalizada), `db.statement` (sanitizado), `error` (bool/message).
- [ ] Spans anidados reflejan la estructura de la llamada (child spans).
- [ ] Eventos (span events) marcan hitos internos.

---

#### `OBS-TRACE-003` — Muestreo inteligente
**Severidad:** medium · **Aplica a:** observability

No todas las trazas se guardan (costo); el muestreo preserva las interesantes
(errores, latencia alta).

**Verificar:**
- [ ] Head sampling razonable (ej: 10% base).
- [ ] Tail sampling si es posible: se guardan todas las trazas con error o latencia > umbral.
- [ ] Configuración del sampler documentada.

---

#### `OBS-TRACE-004` — Correlación logs ↔ trazas
**Severidad:** high · **Aplica a:** backend · observability

Desde un log se puede saltar a la traza asociada, y viceversa.

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

**Verificar:**
- [ ] Cada alerta documenta: qué significa, cómo validar, cómo mitigar.
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

**Verificar:**
- [ ] `GET /healthz` / `/livez` liveness: respuesta rápida, no toca dependencias.
- [ ] `GET /readyz` readiness: valida BD, cache, deps críticas. Devuelve 503 si alguna no está lista.
- [ ] Orchestrator (K8s) usa ambos con timeouts apropiados.
- [ ] No se confunden: un DB caído hace readiness fail, pero no necesariamente liveness.

---

#### `OBS-HEALTH-002` — Métricas de dependencias externas
**Severidad:** medium · **Aplica a:** backend · observability

Se miden tiempos y errores de las dependencias externas (BD, APIs terceros).

**Verificar:**
- [ ] Latencia y error rate por dependencia.
- [ ] Alertas si una dependencia está degradada.
- [ ] Correlación entre dep down y afectación de endpoints.

---

## E. Runbooks y post-mortem

#### `OBS-RUN-001` — Runbooks para alertas críticas
**Severidad:** medium · **Aplica a:** observability · infra

Cada alerta crítica enlaza un runbook accionable.

**Verificar:**
- [ ] Runbooks versionados (repo/wiki).
- [ ] Incluyen: síntomas, diagnóstico, mitigación, escalation.
- [ ] Se revisan y actualizan tras cada incidente.

---

#### `OBS-RUN-002` — Post-mortem blameless tras incidentes
**Severidad:** medium · **Aplica a:** process

Cada incidente significativo produce un post-mortem con lecciones y acciones.

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
