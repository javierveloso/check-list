# 10 · Observabilidad · Logs y métricas

> Logs estructurados, métricas operativas (RED/USE) y presupuestos de error.
>
> **Marcos de referencia:** Google SRE book · OpenTelemetry · RED method (Rate, Errors, Duration) · USE method (Utilization, Saturation, Errors).

---

## A. Logging

#### `OBS-LOG-001` — Logs estructurados (JSON) en producción
**Severidad:** high · **Aplica a:** backend · infra

Los logs se emiten como JSON con campos consistentes, no solo texto plano.

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

**Verificar:**
- [ ] Capa de redacción en el logger (campos allowlist/blocklist).
- [ ] Errores de validación no reflejan el payload completo.
- [ ] Stack traces sin variables sensibles.
- [ ] Revisión periódica de logs en staging para detectar leaks.

---

#### `OBS-LOG-005` — Retención y agregación
**Severidad:** medium · **Aplica a:** infra

Los logs se envían a un backend centralizado con retención definida.

**Verificar:**
- [ ] Stack de logs (Elastic, Loki, Datadog, CloudWatch) configurado.
- [ ] Retención alineada con necesidad operacional y política de datos.
- [ ] Búsqueda/filtrado por request_id y otros campos.
- [ ] Alertas sobre patrones en logs (ej: error spikes).

---

#### `OBS-LOG-006` — Logs frontend
**Severidad:** medium · **Aplica a:** frontend

Errores no manejados en el frontend se capturan y envían al backend (Sentry,
Datadog RUM).

**Verificar:**
- [ ] `window.onerror` / `unhandledrejection` capturados.
- [ ] Source maps suben al error tracker para simbolicación.
- [ ] PII filtrada antes de enviar.
- [ ] Sampling configurado para no ahogar cuota.

---

## B. Métricas RED / USE

#### `OBS-MET-001` — Métricas RED por endpoint/servicio
**Severidad:** high · **Aplica a:** backend · observability

Para cada endpoint crítico: **R**ate (req/s), **E**rrors (% 5xx), **D**uration
(latencia p50/p95/p99).

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

**Verificar:**
- [ ] Uso (%) y saturación (wait) medidos.
- [ ] Pool de BD: conexiones activas vs máximas.
- [ ] Pool de HTTP client: idle vs activas.
- [ ] Cola de background jobs: profundidad y latencia.

---

#### `OBS-MET-003` — Métricas de negocio
**Severidad:** medium · **Aplica a:** backend

Además de métricas técnicas, se miden eventos clave del negocio.

**Verificar:**
- [ ] Signups, logins, conversions, churn.
- [ ] Volumen por operación crítica (pagos, uploads, análisis).
- [ ] Trend dashboards visibles al equipo de producto.

---

#### `OBS-MET-004` — Cardinalidad controlada
**Severidad:** medium · **Aplica a:** observability

Los labels/tags de las métricas no explotan en cardinalidad (explota costo y
rompe store).

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
