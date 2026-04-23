# 02 · API · Idempotencia, concurrencia y operaciones asíncronas

> Idempotency keys, concurrencia optimista, operaciones batch, long-running
> operations (LRO), webhooks y streams.
>
> **Marcos de referencia:** RFC 7232 (Conditional Requests) · Stripe Idempotency · AEP-151 (LRO).

---

## A. Idempotencia en POST

#### `API-IDEM-001` — `Idempotency-Key` soportado en operaciones críticas
**Severidad:** high · **Tags:** `idempotency`, `billing` · **Aplica a:** api · backend

POST que generan efectos costosos o irreversibles (cobro, envío de email, creación
de recurso único) deben aceptar `Idempotency-Key` para evitar duplicados por
reintento del cliente.

**Verificar:**
- [ ] Los endpoints críticos (pagos, envíos, creaciones únicas) aceptan `Idempotency-Key`.
- [ ] La misma key + mismo body → misma respuesta (cacheada por 24 h como mínimo).
- [ ] Key + body distinto → 409 con indicación clara.
- [ ] Hay sistema de almacenamiento con TTL (Redis, BD) para las keys.
- [ ] Documentado qué endpoints la soportan y por cuánto tiempo.

**Banderas rojas:**
- Endpoint `/charges` sin `Idempotency-Key` y retry del cliente produce doble cargo.
- Key ignorada silenciosamente.

**Referencias:** IETF draft-ietf-httpapi-idempotency-key-header.

---

#### `API-IDEM-002` — Reintentos seguros en clientes
**Severidad:** medium · **Aplica a:** frontend · backend (como cliente)

Los clientes que hacen retries usan la misma `Idempotency-Key` por intento, y
solo reintentan ante fallos recuperables.

**Verificar:**
- [ ] Reintento genera misma key por lote lógico, no una nueva por cada intento.
- [ ] Se respeta `Retry-After`.
- [ ] Backoff exponencial con jitter.
- [ ] No se reintenta 4xx (excepto 408, 425, 429 cuando sea semánticamente correcto).

---

## B. Concurrencia optimista

#### `API-IDEM-003` — ETag / If-Match para updates
**Severidad:** high · **Tags:** `rfc-7232`, `lost-update` · **Aplica a:** api · backend

Las actualizaciones sobre recursos que pueden modificarse concurrentemente usan
`ETag` + `If-Match` para detectar conflicts.

**Verificar:**
- [ ] Recursos mutables exponen `ETag` en GET.
- [ ] PUT/PATCH aceptan `If-Match: <etag>` y retornan 412 si no coincide.
- [ ] Sin `If-Match`, se decide una política (rechazar con 428 o aceptar "last write wins" documentado).

**Banderas rojas:**
- Updates sin control de concurrencia en recursos críticos: el último escribe gana silenciosamente.

---

#### `API-IDEM-004` — Locking pesimista solo cuando sea necesario
**Severidad:** medium · **Aplica a:** backend

Se prefiere concurrencia optimista (ETag); pesimista (SELECT FOR UPDATE, advisory
locks) solo cuando el costo de conflict es alto.

**Verificar:**
- [ ] Los locks pesimistas tienen timeout.
- [ ] No se usan en caminos de lectura.
- [ ] Se documenta el scope (row, table, tenant).

---

## C. Batch operations

#### `API-BATCH-001` — Batch con límite y resultado granular
**Severidad:** high · **Aplica a:** api · backend

Si la API acepta operaciones en lote, cada lote está limitado y la respuesta
refleja el resultado por item.

**Verificar:**
- [ ] Tamaño máximo del batch documentado (ej: 100 items).
- [ ] Respuesta indica por cada item: éxito / error con su código y detalle.
- [ ] Política clara: fail-fast vs best-effort (y documentada).
- [ ] Cuando es best-effort, la respuesta usa 207 Multi-Status o estructura equivalente.

**Ejemplo:**
```json
{
  "results": [
    { "index": 0, "status": "created", "id": "abc-1" },
    { "index": 1, "status": "error", "code": "validation_failed", "errors": [...] },
    { "index": 2, "status": "created", "id": "abc-3" }
  ]
}
```

---

#### `API-BATCH-002` — Idempotencia en batch
**Severidad:** medium · **Aplica a:** api

Los batch operations también respetan `Idempotency-Key`, y el cliente puede
reintentar sin duplicar lo ya procesado.

---

## D. Long-Running Operations (LRO)

#### `API-ASYNC-001` — Patrón LRO uniforme
**Severidad:** high · **Tags:** `long-running` · **Aplica a:** api · backend

Las operaciones que toman > ~1–2 s (análisis pesado, exports, indexación) se
modelan como operación asíncrona, no se bloquean en el request HTTP.

**Verificar:**
- [ ] `POST /resources/{id}/long-action` retorna `202 Accepted` con identificador de tarea.
- [ ] Se puede consultar estado: `GET /tasks/{task_id}` o link `Location` en la respuesta.
- [ ] Estados claros: `pending`, `running`, `succeeded`, `failed`, `cancelled`.
- [ ] La tarea tiene timeout máximo.
- [ ] La respuesta al completar incluye link al recurso resultado (si aplica).
- [ ] Las tareas fallidas tienen mensaje legible y código.
- [ ] El cliente puede cancelar: `DELETE /tasks/{task_id}`.

**Banderas rojas:**
- Endpoints "que a veces tardan 30s" bloqueando worker HTTP.
- Estado binario "hecho/no hecho" sin progreso.

---

#### `API-ASYNC-002` — Polling con intervalo adecuado, o webhooks, o streaming
**Severidad:** medium · **Aplica a:** api

El cliente no adivina cuándo preguntar por el estado. El servidor recomienda
intervalo o usa push.

**Verificar:**
- [ ] Header `Retry-After` en el 202 inicial y en respuestas intermedias.
- [ ] Idealmente: webhook al completar (si el cliente soporta), o SSE/streaming.
- [ ] El endpoint de estado es ligero (no recalcula en cada llamada).

---

#### `API-ASYNC-003` — Idempotencia de LRO
**Severidad:** medium · **Aplica a:** api · backend

Crear dos veces la misma tarea con la misma key retorna la misma tarea, no crea
dos.

**Verificar:**
- [ ] Los LRO aceptan `Idempotency-Key`.
- [ ] El task_id es opaco y no revela información interna.

---

## E. Webhooks (salientes del sistema)

#### `API-HOOK-001` — Firma de webhook verificable
**Severidad:** critical · **Tags:** `security`, `integrity` · **Aplica a:** backend

Los webhooks que envía el sistema incluyen firma HMAC verificable por el
receptor.

**Verificar:**
- [ ] Header con firma (ej: `X-Signature: sha256=...`).
- [ ] Timestamp en header (`X-Timestamp`) para prevenir replay.
- [ ] La documentación explica cómo verificar.
- [ ] Rotación de secretos soportada (permite múltiples secrets simultáneamente durante la rotación).

(Ver también `SEC-CRYPTO-040` para validación en webhooks entrantes.)

---

#### `API-HOOK-002` — Reintentos y DLQ en envío de webhooks
**Severidad:** high · **Aplica a:** backend

Si el receptor falla, el sistema reintenta con backoff y acumula fallos en una
cola muerta tras N intentos.

**Verificar:**
- [ ] Reintentos con backoff exponencial.
- [ ] Número máximo de intentos configurado.
- [ ] DLQ o similar para fallos permanentes.
- [ ] UI/log para que el dueño del webhook vea fallos y pueda re-entregar manualmente.
- [ ] Timeouts de entrega definidos.

---

#### `API-HOOK-003` — Eventos entregados con at-least-once y receptor idempotente
**Severidad:** high · **Tags:** `idempotency` · **Aplica a:** api · backend

Los webhooks se entregan at-least-once; el receptor debe manejar duplicados.
El sistema emisor usa `event_id` único para ayudar al receptor a deduplicar.

**Verificar:**
- [ ] Cada evento lleva `event_id` único y estable.
- [ ] Se documenta que el receptor debe deduplicar.
- [ ] El sistema no envía el mismo evento con distintos IDs por reintento.

---

## F. Streams y SSE

#### `API-STREAM-001` — Server-Sent Events / streaming documentado
**Severidad:** medium · **Aplica a:** api

Si la API usa SSE o streaming HTTP, hay política clara de heartbeats,
reconnection e IDs de eventos.

**Verificar:**
- [ ] Heartbeat periódico (ej: comment `: heartbeat` cada 15 s).
- [ ] `id:` en cada evento y soporte para `Last-Event-ID` en reconexión.
- [ ] Timeout de reconexión documentado (`retry:`).
- [ ] Backpressure en el servidor (no acumular infinitamente si el cliente es lento).

---

## Checklist resumen

| ID                | Control                                                | Severidad |
| ----------------- | ------------------------------------------------------ | --------- |
| API-IDEM-001      | Idempotency-Key en críticos                            | high      |
| API-IDEM-002      | Reintentos seguros en clientes                         | medium    |
| API-IDEM-003      | ETag / If-Match en updates                             | high      |
| API-IDEM-004      | Locking pesimista justificado                          | medium    |
| API-BATCH-001     | Batch con límite y resultado granular                  | high      |
| API-BATCH-002     | Idempotencia en batch                                  | medium    |
| API-ASYNC-001     | Patrón LRO uniforme                                    | high      |
| API-ASYNC-002     | Polling/webhook/streaming apropiado                    | medium    |
| API-ASYNC-003     | Idempotencia en LRO                                    | medium    |
| API-HOOK-001      | Firma de webhook                                       | critical  |
| API-HOOK-002      | Reintentos y DLQ en webhooks                           | high      |
| API-HOOK-003      | Entrega at-least-once + event_id                       | high      |
| API-STREAM-001    | SSE/streaming con heartbeat y reconnection             | medium    |
